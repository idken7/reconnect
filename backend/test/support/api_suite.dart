import 'dart:convert';

import 'package:reconnect_backend/auth/password_hasher.dart';
import 'package:reconnect_backend/auth/tokens.dart';
import 'package:reconnect_backend/config.dart';
import 'package:reconnect_backend/db/repository.dart';
import 'package:reconnect_backend/models.dart';
import 'package:reconnect_backend/services/rate_limiter.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'harness.dart';

typedef RepoFactory = Future<Repository> Function();

/// Route-level integration tests for every endpoint and failure path in
/// docs/API_CONTRACT.md. Runs against any [Repository] implementation.
void defineApiSuite(String label, RepoFactory createRepo) {
  group('API ($label)', () {
    late Repository repo;
    late TestApp app;

    setUp(() async {
      repo = await createRepo();
      app = TestApp(repo);
    });

    group('errors and plumbing', () {
      test('unknown route returns the contract error shape', () async {
        final r = await app.get('/v1/nope');
        expect(r.status, 404);
        expect(r.json, containsPair('code', 'not_found'));
        expect(r.json['requestId'], isNotEmpty);
        expect(r.headers['x-request-id'], r.json['requestId']);
      });

      test('health and ready', () async {
        final health = await app.get('/health');
        expect(health.status, 200);
        expect(health.json, {'status': 'ok'});
        final ready = await app.get('/ready');
        expect(ready.status, 200);
        expect(ready.json, {'status': 'ok'});
      });

      test('ready returns 503 when the database is unreachable', () async {
        final down = TestApp(_UnreachableRepository());
        final r = await down.get('/ready');
        expect(r.status, 503);
        expect(r.json['code'], 'not_ready');
        final health = await down.get('/health');
        expect(health.status, 200);
      });

      test('security headers are set on success and error responses', () async {
        for (final r in [await app.get('/health'), await app.get('/v1/nope')]) {
          expect(r.headers['x-content-type-options'], 'nosniff');
          expect(r.headers['strict-transport-security'], contains('max-age'));
          expect(r.headers['x-frame-options'], 'DENY');
          expect(r.headers['content-security-policy'], contains("default-src 'none'"));
          expect(r.headers['cache-control'], 'no-store');
        }
      });

      test('CORS only echoes configured origins and never uses *', () async {
        final allowed = await app.call('GET', '/health', headers: {'origin': 'https://app.example.test'});
        expect(allowed.headers['access-control-allow-origin'], 'https://app.example.test');
        final denied = await app.call('GET', '/health', headers: {'origin': 'https://evil.example'});
        expect(denied.headers.containsKey('access-control-allow-origin'), isFalse);
        final plain = await app.get('/health');
        expect(plain.headers.containsKey('access-control-allow-origin'), isFalse);

        final preflight = await app.call('OPTIONS', '/v1/auth/login', headers: {
          'origin': 'https://app.example.test',
          'access-control-request-method': 'POST',
        });
        expect(preflight.status, 204);
        expect(preflight.headers['access-control-allow-origin'], 'https://app.example.test');
        final badPreflight = await app.call('OPTIONS', '/v1/auth/login', headers: {'origin': 'https://evil.example'});
        expect(badPreflight.headers.containsKey('access-control-allow-origin'), isFalse);
      });

      test('unexpected failures return a generic 500 and are logged, not leaked', () async {
        final broken = TestApp(_ThrowingRepository());
        final r = await broken.post('/v1/auth/login', {'email': 'a@example.test', 'password': 'whatever-password'});
        expect(r.status, 500);
        expect(r.json['code'], 'internal_error');
        expect(r.json['requestId'], isNotEmpty);
        expect(r.raw, isNot(contains('secret db detail')));
        expect(r.raw, isNot(contains('StateError')));
        expect(broken.logs.join('\n'), contains('unhandled error'));
        expect(broken.logs.join('\n'), contains('requestId'));
      });

      test('malformed JSON, non-objects and wrong types return 400', () async {
        for (final raw in ['{not json', '[1,2]', '"text"', '{"email": ', '\u0000\u0001']) {
          final r = await app.call('POST', '/v1/auth/login', rawBody: raw);
          expect(r.status, 400, reason: raw);
          expect(r.code, 'validation_error', reason: raw);
        }
        final badBytes = await app.handler(Request(
          'POST',
          Uri.parse('http://localhost/v1/auth/login'),
          body: [0xff, 0xfe, 0xfd],
        ));
        expect(badBytes.statusCode, 400);

        for (final body in [
          {'email': 5, 'password': 'x'},
          {'email': 'a@example.test', 'password': 12345678},
          {'email': ['a'], 'password': 'x'},
          {'email': 'a@example.test'},
          <String, Object?>{},
        ]) {
          final r = await app.post('/v1/auth/login', body);
          expect(r.status, 400, reason: '$body');
          expect(r.code, 'validation_error');
        }
      });

      test('oversized bodies get 413 (declared length and streamed)', () async {
        final huge = jsonEncode({'email': 'a@example.test', 'password': 'x' * (1024 * 1024 + 10)});
        final declared = await app.call('POST', '/v1/auth/login', rawBody: huge);
        expect(declared.status, 413);
        expect(declared.code, 'payload_too_large');

        final streamed = await app.handler(Request(
          'POST',
          Uri.parse('http://localhost/v1/auth/login'),
          headers: {'x-forwarded-for': '10.0.0.9'},
          body: Stream<List<int>>.fromIterable([
            utf8.encode('{"email":"a@example.test","password":"'),
            List<int>.filled(1024 * 1024 + 1, 0x78),
          ]),
        ));
        expect(streamed.statusCode, 413);
      });

      test('every authenticated route rejects missing and invalid tokens', () async {
        const routes = [
          ['GET', '/v1/dashboard'],
          ['POST', '/v1/contacts/import'],
          ['GET', '/v1/contacts/matches'],
          ['PATCH', '/v1/contacts/someone/preference'],
          ['PATCH', '/v1/location'],
          ['PATCH', '/v1/profile'],
          ['POST', '/v1/auth/logout'],
          ['POST', '/v1/auth/logout-all'],
          ['POST', '/v1/auth/verify/phone/send'],
          ['POST', '/v1/auth/verify/phone/confirm'],
          ['POST', '/v1/auth/verify/email/send'],
          ['POST', '/v1/auth/verify/email/confirm'],
          ['GET', '/v1/account/export'],
          ['DELETE', '/v1/account'],
        ];
        for (final route in routes) {
          final none = await app.call(route[0], route[1], body: const {});
          expect(none.status, 401, reason: route.join(' '));
          expect(none.code, 'missing_bearer_token', reason: route.join(' '));
          final bad = await app.call(route[0], route[1], body: const {}, token: 'not-a-real-token');
          expect(bad.status, 401, reason: route.join(' '));
          expect(bad.code, 'invalid_access_token', reason: route.join(' '));
        }
        final basic = await app.call('GET', '/v1/dashboard', headers: {'authorization': 'Basic abc'});
        expect(basic.code, 'missing_bearer_token');
      });

      test('logs never contain passwords, emails, phones or tokens', () async {
        final s = await app.signUp(1);
        await app.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        await app.post('/v1/auth/login', {'email': s.email, 'password': 'wrong-password-123'});
        await app.get('/v1/dashboard', token: s.access);
        final logs = app.logs.join('\n');
        expect(logs, isNotEmpty);
        for (final secret in [s.password, s.email, s.phone, s.access, s.refresh, 'wrong-password-123']) {
          expect(logs, isNot(contains(secret)));
        }
      });
    });

    group('signup', () {
      test('creates an account and returns a session response', () async {
        final r = await app.post('/v1/auth/signup', {
          'email': '  New.User@Example.TEST ',
          'phone': '(415) 555-2000',
          'password': strongPassword,
          'name': 'New User',
          'homeCity': 'Austin',
          'bio': 'hi',
        });
        expect(r.status, 200, reason: r.raw);
        final json = r.json;
        expect(json['accessToken'], isNotEmpty);
        expect(json['refreshToken'], isNotEmpty);
        expect(json['token'], json['accessToken']);
        expect(DateTime.parse(json['accessTokenExpiresAt'] as String).isAfter(app.clock.now), isTrue);
        expect(json['profile'], {
          'name': 'New User',
          'email': 'new.user@example.test',
          'phone': '+14155552000',
          'homeCity': 'Austin',
          'bio': 'hi',
          'profileImageUrl': '',
          'emailVerified': false,
          'phoneVerified': false,
          'locationShared': false,
        });
        expect(app.provider.sendsTo('+14155552000'), 1, reason: 'phone code sent on signup');
        expect(json.containsKey('passwordHash'), isFalse);
      });

      test('duplicate email or phone returns 409 account_exists', () async {
        await app.signUp(1);
        final sameEmail = await app.post('/v1/auth/signup', {
          'email': TestApp.emailFor(1).toUpperCase(),
          'phone': TestApp.phoneFor(2),
          'password': strongPassword,
        });
        expect(sameEmail.status, 409);
        expect(sameEmail.code, 'account_exists');
        final samePhone = await app.post('/v1/auth/signup', {
          'email': TestApp.emailFor(3),
          'phone': '415-555-1001',
          'password': strongPassword,
        });
        expect(samePhone.status, 409);
        expect(samePhone.code, 'account_exists');
      });

      test('rejects invalid input', () async {
        Future<void> expectBad(Map<String, Object?> overrides, String why) async {
          final r = await app.post('/v1/auth/signup', {
            'email': TestApp.emailFor(50),
            'phone': TestApp.phoneFor(50),
            'password': strongPassword,
            ...overrides,
          });
          expect(r.status, 400, reason: why);
          expect(r.code, 'validation_error', reason: why);
        }

        await expectBad({'email': 'not-an-email'}, 'bad email');
        await expectBad({'email': 'a@b'}, 'no tld');
        await expectBad({'phone': '555-1234'}, 'too short phone');
        await expectBad({'phone': 'call me maybe'}, 'letters in phone');
        await expectBad({'phone': '+0123456789'}, 'leading zero');
        await expectBad({'password': 'short1'}, 'short password');
        await expectBad({'password': 'password123'}, 'common password');
        await expectBad({'password': 'Password1!'}, 'common password with decoration');
        await expectBad({'password': 'qwertyuiop'}, 'common password');
        await expectBad({'password': 12345678}, 'wrong type');
        await expectBad({'name': 5}, 'wrong type');
        await expectBad({'name': 'x' * 101}, 'long name');
        await expectBad({'bio': 'x' * 501}, 'long bio');
        await expectBad({'phone': null}, 'missing phone');
      });

      test('accepts international E.164 phones', () async {
        final r = await app.post('/v1/auth/signup', {
          'email': 'intl@example.test',
          'phone': '+44 20 7946 0958',
          'password': strongPassword,
        });
        expect(r.status, 200, reason: r.raw);
        expect(r.json['profile']['phone'], '+442079460958');
      });

      test('stores passwords as salted Argon2id with parameters, never plaintext', () async {
        final s = await app.signUp(1);
        final user = (await repo.findUserByEmail(s.email))!;
        expect(user.passwordHash, startsWith(r'$argon2id$v=19$m='));
        expect(user.passwordHash, isNot(contains(s.password)));
        await app.signUp(2);
        final other = (await repo.findUserByEmail(TestApp.emailFor(2)))!;
        expect(other.passwordHash, isNot(user.passwordHash), reason: 'same password, different salt');
      });
    });

    group('login', () {
      test('returns a session response', () async {
        final s = await app.signUp(1);
        final r = await app.post('/v1/auth/login', {'email': s.email.toUpperCase(), 'password': s.password, 'deviceLabel': 'iPhone'});
        expect(r.status, 200, reason: r.raw);
        expect(r.json['accessToken'], isNot(s.access));
        expect(r.json['token'], r.json['accessToken']);
        expect(r.json['profile']['email'], s.email);
      });

      test('does not invalidate other sessions', () async {
        final s = await app.signUp(1);
        final second = await app.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        final third = await app.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        for (final token in [s.access, second.json['accessToken'], third.json['accessToken']]) {
          final r = await app.get('/v1/dashboard', token: token as String);
          expect(r.status, 200);
        }
      });

      test('unknown email and wrong password are indistinguishable', () async {
        final s = await app.signUp(1);
        final wrong = await app.post('/v1/auth/login', {'email': s.email, 'password': 'not-the-password-1'});
        final unknown = await app.post('/v1/auth/login', {'email': 'nobody@example.test', 'password': 'not-the-password-1'});
        final malformed = await app.post('/v1/auth/login', {'email': 'not an email', 'password': 'not-the-password-1'});
        for (final r in [wrong, unknown, malformed]) {
          expect(r.status, 401);
          expect(r.code, 'invalid_credentials');
        }
        expect(unknown.json['error'], wrong.json['error']);
        expect(malformed.json['error'], wrong.json['error']);
      });

      test('does the same hashing work for unknown email and wrong password', () async {
        final hasher = _CountingHasher();
        final counted = TestApp(repo, hasher: hasher);
        final s = await counted.signUp(1);
        hasher.verifies = 0;
        await counted.post('/v1/auth/login', {'email': s.email, 'password': 'not-the-password-1'});
        final afterWrong = hasher.verifies;
        await counted.post('/v1/auth/login', {'email': 'nobody@example.test', 'password': 'not-the-password-1'});
        expect(afterWrong, 1);
        expect(hasher.verifies - afterWrong, 1);
      });

      test('upgrades outdated password hash parameters on login', () async {
        final s = await app.signUp(1);
        final before = (await repo.findUserByEmail(s.email))!.passwordHash;
        expect(before, contains('m=64,t=1,p=1'));

        final stronger = TestApp(repo, hasher: PasswordHasher(params: const Argon2Params(memoryKiB: 128, iterations: 2)));
        final r = await stronger.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        expect(r.status, 200, reason: r.raw);
        final after = (await repo.findUserByEmail(s.email))!.passwordHash;
        expect(after, contains('m=128,t=2,p=1'));
        final again = await stronger.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        expect(again.status, 200);
        expect((await repo.findUserByEmail(s.email))!.passwordHash, after, reason: 'no rehash when params match');
      });
    });

    group('tokens', () {
      test('refresh rotates the refresh token and returns a new access token', () async {
        final s = await app.signUp(1);
        final r = await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        expect(r.status, 200, reason: r.raw);
        expect(r.json['refreshToken'], isNot(s.refresh));
        expect(r.json['accessToken'], isNot(s.access));
        expect(r.json['token'], r.json['accessToken']);
        expect(r.json.containsKey('profile'), isFalse);
        expect((await app.get('/v1/dashboard', token: r.json['accessToken'] as String)).status, 200);
        final again = await app.post('/v1/auth/refresh', {'refreshToken': r.json['refreshToken']});
        expect(again.status, 200);
      });

      test('reusing a rotated refresh token revokes the whole session family', () async {
        final s = await app.signUp(1);
        final first = await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        final newest = first.json['refreshToken'] as String;
        final newestAccess = first.json['accessToken'] as String;

        final replay = await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        expect(replay.status, 401);
        expect(replay.code, 'refresh_token_reused');

        final afterRevoke = await app.post('/v1/auth/refresh', {'refreshToken': newest});
        expect(afterRevoke.status, 401);
        expect(afterRevoke.code, 'invalid_refresh_token');
        expect((await app.get('/v1/dashboard', token: newestAccess)).code, 'invalid_access_token');
        expect((await app.get('/v1/dashboard', token: s.access)).code, 'invalid_access_token');
      });

      test('reuse revokes only the affected session, not the other devices', () async {
        final s = await app.signUp(1);
        final other = await app.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        expect((await app.get('/v1/dashboard', token: other.json['accessToken'] as String)).status, 200);
      });

      test('invalid, empty and expired refresh tokens', () async {
        final s = await app.signUp(1);
        final bogus = await app.post('/v1/auth/refresh', {'refreshToken': 'bogus'});
        expect(bogus.status, 401);
        expect(bogus.code, 'invalid_refresh_token');
        final empty = await app.post('/v1/auth/refresh', {'refreshToken': ''});
        expect(empty.status, 400);
        final missing = await app.post('/v1/auth/refresh', {});
        expect(missing.status, 400);
        final wrongType = await app.post('/v1/auth/refresh', {'refreshToken': 7});
        expect(wrongType.status, 400);

        app.clock.advance(const Duration(days: 31));
        final expired = await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        expect(expired.status, 401);
        expect(expired.code, 'refresh_token_expired');
      });

      test('expired access tokens return token_expired and refresh restores access', () async {
        final s = await app.signUp(1);
        app.clock.advance(const Duration(minutes: 16));
        final expired = await app.get('/v1/dashboard', token: s.access);
        expect(expired.status, 401);
        expect(expired.code, 'token_expired');
        final refreshed = await app.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        expect((await app.get('/v1/dashboard', token: refreshed.json['accessToken'] as String)).status, 200);
      });

      test('tokens are stored hashed, never raw', () async {
        final s = await app.signUp(1);
        expect(await repo.findAccessToken(hashToken(s.access)), isNotNull);
        expect(await repo.findAccessToken(s.access), isNull);
        expect(await repo.findRefreshToken(hashToken(s.refresh)), isNotNull);
        expect(await repo.findRefreshToken(s.refresh), isNull);
      });

      test('logout revokes only the presented session', () async {
        final s = await app.signUp(1);
        final other = await app.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        final otherAccess = other.json['accessToken'] as String;
        final r = await app.post('/v1/auth/logout', {}, token: s.access);
        expect(r.status, 200);
        expect(r.json, {'ok': true});
        expect((await app.get('/v1/dashboard', token: s.access)).code, 'invalid_access_token');
        expect((await app.post('/v1/auth/refresh', {'refreshToken': s.refresh})).code, 'invalid_refresh_token');
        expect((await app.get('/v1/dashboard', token: otherAccess)).status, 200);
      });

      test('logout-all revokes every session', () async {
        final s = await app.signUp(1);
        final other = await app.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        final r = await app.post('/v1/auth/logout-all', {}, token: s.access);
        expect(r.status, 200);
        expect(r.json, {'ok': true});
        expect((await app.get('/v1/dashboard', token: s.access)).status, 401);
        expect((await app.get('/v1/dashboard', token: other.json['accessToken'] as String)).status, 401);
        expect((await app.post('/v1/auth/refresh', {'refreshToken': other.json['refreshToken']})).status, 401);
        expect((await app.post('/v1/auth/login', {'email': s.email, 'password': s.password})).status, 200);
      });
    });

    group('phone and email verification', () {
      test('send and confirm phone with the delivered code', () async {
        final s = await app.signUp(1);
        final send = await app.post('/v1/auth/verify/phone/send', {}, token: s.access);
        expect(send.status, 200);
        expect(send.json, {'ok': true});
        expect(app.provider.sendsTo(s.phone), 2);
        final code = app.provider.lastCodeFor(s.phone)!;
        expect(code, matches(RegExp(r'^\d{6}$')));

        final confirm = await app.post('/v1/auth/verify/phone/confirm', {'code': code}, token: s.access);
        expect(confirm.status, 200, reason: confirm.raw);
        expect(confirm.json['profile']['phoneVerified'], isTrue);
        expect(confirm.json['profile']['emailVerified'], isFalse);

        final reuse = await app.post('/v1/auth/verify/phone/confirm', {'code': code}, token: s.access);
        expect(reuse.status, 200, reason: 'already verified is idempotent');
      });

      test('wrong, malformed and expired codes are rejected', () async {
        final s = await app.signUp(1);
        final real = app.provider.lastCodeFor(s.phone)!;
        final wrong = real == '123456' ? '654321' : '123456';
        final bad = await app.post('/v1/auth/verify/phone/confirm', {'code': wrong}, token: s.access);
        expect(bad.status, 400);
        expect(bad.code, 'validation_error');
        for (final code in ['12345', '1234567', 'abcdef', '', 123456]) {
          final r = await app.post('/v1/auth/verify/phone/confirm', {'code': code}, token: s.access);
          expect(r.status, 400, reason: '$code');
        }
        expect((await app.post('/v1/auth/verify/phone/confirm', {}, token: s.access)).status, 400);

        app.clock.advance(const Duration(minutes: 11));
        final expired = await app.post('/v1/auth/verify/phone/confirm', {'code': real}, token: s.access);
        expect(expired.status, 400);
      });

      test('a code stops working after too many wrong attempts', () async {
        final s = await app.signUp(1);
        final real = app.provider.lastCodeFor(s.phone)!;
        final wrong = real == '111111' ? '222222' : '111111';
        for (var i = 0; i < 5; i++) {
          expect((await app.post('/v1/auth/verify/phone/confirm', {'code': wrong}, token: s.access)).status, 400);
        }
        final lockedOut = await app.post('/v1/auth/verify/phone/confirm', {'code': real}, token: s.access);
        expect(lockedOut.status, 400);
        expect(lockedOut.json['error'], contains('Too many'));

        await app.post('/v1/auth/verify/phone/send', {}, token: s.access);
        final fresh = app.provider.lastCodeFor(s.phone)!;
        expect((await app.post('/v1/auth/verify/phone/confirm', {'code': fresh}, token: s.access)).status, 200);
      });

      test('000000 works outside production with the console provider', () async {
        final s = await app.signUp(1);
        final r = await app.post('/v1/auth/verify/phone/confirm', {'code': '000000'}, token: s.access);
        expect(r.status, 200);
        expect(r.json['profile']['phoneVerified'], isTrue);
      });

      test('000000 is rejected in production', () async {
        final prod = TestApp(repo, config: testConfig(env: AppEnv.production));
        final s = await prod.signUp(1);
        final r = await prod.post('/v1/auth/verify/phone/confirm', {'code': '000000'}, token: s.access);
        expect(r.status, 400);
        final real = prod.provider.lastCodeFor(s.phone)!;
        if (real != '000000') {
          expect((await prod.post('/v1/auth/verify/phone/confirm', {'code': real}, token: s.access)).status, 200);
        }
      });

      test('email send and confirm', () async {
        final s = await app.signUp(1);
        expect((await app.post('/v1/auth/verify/email/send', {}, token: s.access)).status, 200);
        final code = app.provider.lastCodeFor(s.email)!;
        final bad = await app.post('/v1/auth/verify/email/confirm', {'code': code == '999999' ? '888888' : '999999'}, token: s.access);
        expect(bad.status, 400);
        final good = await app.post('/v1/auth/verify/email/confirm', {'code': code}, token: s.access);
        expect(good.status, 200);
        expect(good.json['profile']['emailVerified'], isTrue);
        expect(good.json['profile']['phoneVerified'], isFalse);
      });

      test('codes are hashed at rest', () async {
        final s = await app.signUp(1);
        final code = app.provider.lastCodeFor(s.phone)!;
        final stored = (await repo.findVerificationCode(VerificationPurpose.phoneVerify, s.phone))!;
        expect(stored.codeHash, isNotNull);
        expect(stored.codeHash, isNot(code));
        expect(stored.codeHash, isNot(contains(code)));
        expect(stored.expiresAt.difference(stored.createdAt), const Duration(minutes: 10));
      });
    });

    group('password reset', () {
      test('request never reveals whether the account exists', () async {
        final s = await app.signUp(1);
        final known = await app.post('/v1/auth/password-reset/request', {'email': s.email});
        final unknown = await app.post('/v1/auth/password-reset/request', {'email': 'ghost@example.test'});
        expect(known.status, 200);
        expect(unknown.status, 200);
        expect(known.json, {'ok': true});
        expect(unknown.json, {'ok': true});
        expect(app.provider.sendsTo(s.email), 1);
        expect(app.provider.sendsTo('ghost@example.test'), 0);
        expect((await app.post('/v1/auth/password-reset/request', {'email': 'garbage'})).status, 400);
        expect((await app.post('/v1/auth/password-reset/request', {})).status, 400);
      });

      test('confirm sets a new password, is single use, and revokes all sessions', () async {
        final s = await app.signUp(1);
        await app.post('/v1/auth/password-reset/request', {'email': s.email});
        final code = app.provider.lastCodeFor(s.email)!;
        const newPassword = 'a brand new passphrase 42';

        final weak = await app.post('/v1/auth/password-reset/confirm', {'email': s.email, 'code': code, 'newPassword': 'password123'});
        expect(weak.status, 400);
        final wrongCode = await app.post('/v1/auth/password-reset/confirm', {
          'email': s.email,
          'code': code == '123456' ? '654321' : '123456',
          'newPassword': newPassword,
        });
        expect(wrongCode.status, 400);

        final ok = await app.post('/v1/auth/password-reset/confirm', {'email': s.email, 'code': code, 'newPassword': newPassword});
        expect(ok.status, 200, reason: ok.raw);
        expect(ok.json, {'ok': true});

        expect((await app.get('/v1/dashboard', token: s.access)).status, 401);
        expect((await app.post('/v1/auth/refresh', {'refreshToken': s.refresh})).status, 401);
        expect((await app.post('/v1/auth/login', {'email': s.email, 'password': s.password})).code, 'invalid_credentials');
        expect((await app.post('/v1/auth/login', {'email': s.email, 'password': newPassword})).status, 200);

        final replay = await app.post('/v1/auth/password-reset/confirm', {'email': s.email, 'code': code, 'newPassword': 'yet another passphrase 7'});
        expect(replay.status, 400);
      });

      test('expired reset codes and unknown emails fail identically', () async {
        final s = await app.signUp(1);
        await app.post('/v1/auth/password-reset/request', {'email': s.email});
        final code = app.provider.lastCodeFor(s.email)!;
        app.clock.advance(const Duration(minutes: 11));
        final expired = await app.post('/v1/auth/password-reset/confirm', {'email': s.email, 'code': code, 'newPassword': 'another good passphrase 1'});
        expect(expired.status, 400);
        // Even the dev shortcut cannot reset an account that never requested it.
        final unknown = await app.post('/v1/auth/password-reset/confirm', {'email': 'ghost@example.test', 'code': '000000', 'newPassword': 'another good passphrase 1'});
        expect(unknown.status, 400);
        expect(unknown.json['error'], expired.json['error']);
      });
    });

    group('profile, location and dashboard', () {
      test('dashboard has the contract shape for a new user', () async {
        final s = await app.signUp(1);
        final r = await app.get('/v1/dashboard', token: s.access);
        expect(r.status, 200);
        expect(r.json['supportedLocations'], ['Brooklyn', 'Manhattan', 'Austin', 'Chicago', 'Other']);
        expect(r.json['currentLocation'], 'Brooklyn');
        expect(r.json['contactsImported'], isFalse);
        expect(r.json['contacts'], isEmpty);
        expect(r.json['suggestions'], isEmpty);
        expect(r.json['profile']['email'], s.email);
      });

      test('dashboard location query sets and validates the current location', () async {
        final s = await app.signUp(1);
        final austin = await app.get('/v1/dashboard?location=Austin', token: s.access);
        expect(austin.json['currentLocation'], 'Austin');
        expect((await app.get('/v1/dashboard', token: s.access)).json['currentLocation'], 'Austin');
        expect((await app.get('/v1/dashboard?location=Mars', token: s.access)).status, 400);
      });

      test('PATCH /location by name and by coordinates; unknown places map to Other', () async {
        final s = await app.signUp(1);
        Future<String> locate(Map<String, Object?> body) async {
          final r = await app.patch('/v1/location', body, token: s.access);
          expect(r.status, 200, reason: r.raw);
          return r.json['currentLocation'] as String;
        }

        expect(await locate({'location': 'Chicago'}), 'Chicago');
        expect(await locate({'latitude': 30.2672, 'longitude': -97.7431}), 'Austin');
        expect(await locate({'latitude': 40.6782, 'longitude': -73.9442}), 'Brooklyn');
        expect(await locate({'latitude': 40.7831, 'longitude': -73.9712}), 'Manhattan');
        expect(await locate({'latitude': 48.8566, 'longitude': 2.3522}), 'Other');
        expect(await locate({'latitude': 0, 'longitude': 0}), 'Other');
        expect(await locate({'location': 'Other'}), 'Other');

        for (final bad in <Map<String, Object?>>[
          {},
          {'location': 'Atlantis'},
          {'location': ''},
          {'location': 5},
          {'latitude': 'x', 'longitude': 1},
          {'latitude': 91, 'longitude': 0},
          {'latitude': 0, 'longitude': 181},
          {'latitude': 40.0},
        ]) {
          final r = await app.patch('/v1/location', bad, token: s.access);
          expect(r.status, 400, reason: '$bad');
          expect(r.code, 'validation_error');
        }
      });

      test('PATCH /profile validates and updates', () async {
        final s = await app.signUp(1);
        final ok = await app.patch('/v1/profile', {
          'bio': 'Updated bio',
          'homeCity': 'Chicago',
          'profileImageUrl': 'https://cdn.example.test/me.png',
          'locationShared': true,
        }, token: s.access);
        expect(ok.status, 200, reason: ok.raw);
        expect(ok.json['profile']['bio'], 'Updated bio');
        expect(ok.json['profile']['homeCity'], 'Chicago');
        expect(ok.json['profile']['profileImageUrl'], 'https://cdn.example.test/me.png');
        expect(ok.json['profile']['locationShared'], isTrue);

        final cleared = await app.patch('/v1/profile', {'profileImageUrl': ''}, token: s.access);
        expect(cleared.json['profile']['profileImageUrl'], '');
        expect(cleared.json['profile']['bio'], 'Updated bio', reason: 'omitted fields are untouched');

        for (final bad in <Map<String, Object?>>[
          {'profileImageUrl': 'http://insecure.example.test/me.png'},
          {'profileImageUrl': 'javascript:alert(1)'},
          {'profileImageUrl': 'https://user:pw@example.test/a.png'},
          {'profileImageUrl': 42},
          {'bio': 42},
          {'bio': 'x' * 501},
          {'homeCity': ['x']},
          {'locationShared': 'yes'},
        ]) {
          final r = await app.patch('/v1/profile', bad, token: s.access);
          expect(r.status, 400, reason: '$bad');
          expect(r.code, 'validation_error');
        }
      });
    });

    group('contacts', () {
      test('import requires a verified phone', () async {
        final s = await app.signUp(1);
        final r = await app.importContacts(s, [
          TestApp.contact('Pat', phones: [TestApp.phoneFor(2)]),
        ]);
        expect(r.status, 403);
        expect(r.code, 'verification_required');
      });

      test('import validates the payload', () async {
        final s = await app.verifiedUser(1);
        final cases = <String, Object?>{
          'contacts missing': <String, Object?>{},
          'contacts not a list': {'contacts': 'x'},
          'contact not an object': {'contacts': ['x']},
          'name wrong type': {'contacts': [{'name': 5}]},
          'phones wrong type': {'contacts': [{'name': 'a', 'phones': 'x'}]},
          'phone item wrong type': {'contacts': [{'name': 'a', 'phones': [5]}]},
          'emails wrong type': {'contacts': [{'name': 'a', 'emails': {'a': 1}}]},
          'bad location': {'contacts': [], 'location': 'Atlantis'},
          'location wrong type': {'contacts': [], 'location': 3},
          'too many contacts': {'contacts': List.generate(5001, (i) => {'name': 'n$i'})},
        };
        for (final entry in cases.entries) {
          final r = await app.post('/v1/contacts/import', entry.value, token: s.access);
          expect(r.status, 400, reason: entry.key);
          expect(r.code, 'validation_error', reason: entry.key);
        }
      });

      test('import allows up to 5000 contacts and up to 5 MB, but not more', () async {
        final s = await app.verifiedUser(1);
        final many = List.generate(
          5000,
          (i) => TestApp.contact('Contact $i', phones: ['+1415556${(i % 10000).toString().padLeft(4, '0')}']),
        );
        final ok = await app.importContacts(s, many);
        expect(ok.status, 200, reason: ok.raw.length > 300 ? ok.raw.substring(0, 300) : ok.raw);
        expect(ok.json['contactsImported'], isTrue);

        // ~2 MB is over the default limit but under the import limit.
        final padded = jsonEncode({
          'contacts': [TestApp.contact('Padded', emails: ['a@example.test'])],
          'location': 'Austin',
          'padding': 'x' * (2 * 1024 * 1024),
        });
        expect((await app.call('POST', '/v1/contacts/import', rawBody: padded, token: s.access)).status, 200);
        final tooBig = jsonEncode({'contacts': [], 'padding': 'x' * (5 * 1024 * 1024 + 1)});
        final big = await app.call('POST', '/v1/contacts/import', rawBody: tooBig, token: s.access);
        expect(big.status, 413);
        expect(big.code, 'payload_too_large');
        // The same 2 MB body is refused on any other route.
        final other = await app.call('PATCH', '/v1/profile', rawBody: padded, token: s.access);
        expect(other.status, 413);
      });

      test('matches follow the contract rules: mutual, oneWay, notOnApp', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        final c = await app.verifiedUser(3);
        final stranger = await app.verifiedUser(4);
        await app.verifyEmail(b);

        // A has B (by email) and C (by phone) and someone unknown; B has A; C has nobody.
        final importA = await app.importContacts(a, [
          TestApp.contact('Bee From Work', emails: [b.email.toUpperCase()]),
          TestApp.contact('Cee', phones: ['(415) 555-1003']),
          TestApp.contact('Nina (not here)', phones: ['+14155559999']),
        ]);
        expect(importA.status, 200, reason: importA.raw);
        await app.importContacts(b, [
          TestApp.contact('Aay', phones: [a.phone], emails: ['junk']),
        ]);

        final matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        final mutual = matches['mutual'] as List;
        final oneWay = matches['oneWay'] as List;
        final notOnApp = matches['notOnApp'] as List;
        expect(mutual, hasLength(1));
        expect(mutual.single['name'], 'Bee From Work', reason: 'name comes from the viewer address book');
        expect(mutual.single['mutual'], isTrue);
        expect(mutual.single['isOnApp'], isTrue);
        expect(mutual.single['preference'], 'neutral');
        expect(oneWay, hasLength(1));
        expect(oneWay.single['name'], 'Cee');
        expect(oneWay.single['mutual'], isFalse);
        expect(notOnApp, [
          {'name': 'Nina (not here)', 'status': 'notOnApp'},
        ]);

        // Other users' identifiers never leak.
        final raw = jsonEncode(matches);
        for (final secret in [b.email, b.phone, c.phone, c.email, stranger.phone, 'User 2', 'User 3']) {
          expect(raw, isNot(contains(secret)));
        }
        final bId = mutual.single['id'] as String;
        expect(bId, isNot(contains('example')));

        // B sees A as mutual too, using B's own name for A.
        final bMatches = (await app.get('/v1/contacts/matches', token: b.access)).json;
        expect((bMatches['mutual'] as List).single['name'], 'Aay');
        expect(bMatches['oneWay'], isEmpty);

        // C was never imported by anyone who C imported; C sees nothing.
        final cMatches = (await app.get('/v1/contacts/matches', token: c.access)).json;
        expect(cMatches, {'mutual': [], 'oneWay': [], 'notOnApp': []});

        // A stranger who is in nobody's address book is invisible to everyone.
        for (final viewer in [a, b, c]) {
          final json = jsonEncode((await app.get('/v1/dashboard', token: viewer.access)).json);
          expect(json, isNot(contains(stranger.phone)));
          expect(json, isNot(contains('User 4')));
        }
        final dashboard = (await app.get('/v1/dashboard', token: a.access)).json;
        expect(dashboard['contactsImported'], isTrue);
        expect((dashboard['contacts'] as List).map((e) => e['name']), ['Bee From Work', 'Cee']);
      });

      test('matches are recomputed on read when a contact verifies later', () async {
        final a = await app.verifiedUser(1);
        final late = await app.signUp(2); // phone not yet verified
        await app.importContacts(a, [
          TestApp.contact('Late Larry', phones: [late.phone], emails: [late.email]),
        ]);
        var matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect(matches['notOnApp'], [
          {'name': 'Late Larry', 'status': 'notOnApp'},
        ]);
        expect(matches['oneWay'], isEmpty);

        await app.verifyPhone(late);
        matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect(matches['notOnApp'], isEmpty);
        expect((matches['oneWay'] as List).single['name'], 'Late Larry');

        // Matching by email alone also works once the email is verified.
        final emailOnly = await app.signUp(3);
        await app.verifyEmail(emailOnly);
        await app.importContacts(a, [
          TestApp.contact('Email Only', emails: [emailOnly.email]),
        ]);
        matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect((matches['oneWay'] as List).single['name'], 'Email Only');
      });

      test('unverified identifiers and self are never matched', () async {
        final a = await app.verifiedUser(1);
        final unverified = await app.signUp(2);
        await app.importContacts(a, [
          TestApp.contact('Squatter', phones: [unverified.phone], emails: [unverified.email]),
          TestApp.contact('Me', phones: [a.phone]),
        ]);
        final matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect(matches['mutual'], isEmpty);
        expect(matches['oneWay'], isEmpty);
        expect(matches['notOnApp'], [
          {'name': 'Squatter', 'status': 'notOnApp'},
        ]);
      });

      test('mutual requires the other side to hold a VERIFIED identifier of the viewer', () async {
        final a = await app.signUp(1);
        await app.verifyPhone(a);
        final b = await app.verifiedUser(2);
        // B imports A's (unverified) email: this does not make them mutual with A's phone-only verified identity.
        await app.importContacts(a, [TestApp.contact('B', phones: [b.phone])]);
        await app.importContacts(b, [TestApp.contact('A by email', emails: [a.email])]);
        var matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect(matches['mutual'], isEmpty);
        expect(matches['oneWay'], hasLength(1));
        await app.verifyEmail(a);
        matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect(matches['mutual'], hasLength(1));
      });

      test('availableIn, lastSeenAt and locationShared privacy rules', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        final c = await app.verifiedUser(3);
        await app.importContacts(a, [
          TestApp.contact('B', phones: [b.phone]),
          TestApp.contact('C', phones: [c.phone]),
        ]);
        await app.importContacts(b, [TestApp.contact('A', phones: [a.phone])]);
        await app.patch('/v1/location', {'location': 'Chicago'}, token: b.access);
        await app.patch('/v1/location', {'location': 'Austin'}, token: c.access);

        Future<Map<String, dynamic>> contactsOfA() async {
          final json = (await app.get('/v1/dashboard', token: a.access)).json;
          return {for (final contact in json['contacts'] as List) contact['name'] as String: contact};
        }

        // Nobody shares yet: no city for anyone.
        var contacts = await contactsOfA();
        expect(contacts['B']['availableIn'], isEmpty);
        expect(contacts['C']['availableIn'], isEmpty);

        // Both opt in; only the MUTUAL contact's city is revealed.
        await app.patch('/v1/profile', {'locationShared': true}, token: b.access);
        await app.patch('/v1/profile', {'locationShared': true}, token: c.access);
        contacts = await contactsOfA();
        expect(contacts['B']['availableIn'], ['Chicago']);
        expect(contacts['B']['lastSeenAt'], isNotNull);
        expect(DateTime.parse(contacts['B']['lastSeenAt'] as String).isUtc, isTrue);
        expect(contacts['C']['mutual'], isFalse);
        expect(contacts['C']['availableIn'], isEmpty, reason: 'one-way matches never expose location');
        expect(contacts['C']['lastSeenAt'], isNull);

        // Opting out hides it again.
        await app.patch('/v1/profile', {'locationShared': false}, token: b.access);
        contacts = await contactsOfA();
        expect(contacts['B']['availableIn'], isEmpty);
      });

      test('suggestions need mutual + shared + same city, and respect preferences', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        final c = await app.verifiedUser(3);
        final d = await app.verifiedUser(4);
        await app.importContacts(a, [
          TestApp.contact('B', phones: [b.phone]),
          TestApp.contact('C', phones: [c.phone]),
          TestApp.contact('D', phones: [d.phone]),
        ]);
        for (final other in [b, c, d]) {
          await app.importContacts(other, [TestApp.contact('A', phones: [a.phone])]);
          await app.patch('/v1/profile', {'locationShared': true}, token: other.access);
        }
        await app.patch('/v1/location', {'location': 'Austin'}, token: b.access);
        await app.patch('/v1/location', {'location': 'Austin'}, token: c.access);
        await app.patch('/v1/location', {'location': 'Chicago'}, token: d.access);
        await app.patch('/v1/location', {'location': 'Austin'}, token: a.access);

        Future<List<dynamic>> suggestions() async =>
            (await app.get('/v1/dashboard', token: a.access)).json['suggestions'] as List;

        var list = await suggestions();
        expect(list.map((s) => s['contact']['name']), ['B', 'C']);
        expect(list.first['reason'], isNotEmpty);
        expect(list.first['distanceLabel'], isNotEmpty);
        expect(list.first['sharedLocations'], ['Austin']);
        expect(list.first['timeSinceLastSeen'], isA<String>());

        final bId = list.first['contact']['id'] as String;
        final cId = list.last['contact']['id'] as String;
        final love = await app.patch('/v1/contacts/$cId/preference', {'preference': 'loveToSee'}, token: a.access);
        expect(love.status, 200, reason: love.raw);
        list = await suggestions();
        expect(list.map((s) => s['contact']['name']), ['C', 'B'], reason: 'loveToSee sorts first');

        await app.patch('/v1/contacts/$bId/preference', {'preference': 'ratherAvoid'}, token: a.access);
        list = await suggestions();
        expect(list.map((s) => s['contact']['name']), ['C']);

        // "Other" never produces suggestions even if everyone is "in" Other.
        await app.patch('/v1/location', {'location': 'Other'}, token: a.access);
        expect(await suggestions(), isEmpty);
      });

      test('preference is private, validated, and limited to known contacts', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        final stranger = await app.verifiedUser(3);
        await app.importContacts(a, [TestApp.contact('B', phones: [b.phone])]);
        await app.importContacts(b, [TestApp.contact('A', phones: [a.phone])]);
        final bId = ((await app.get('/v1/contacts/matches', token: a.access)).json['mutual'] as List).single['id'] as String;
        final aId = ((await app.get('/v1/contacts/matches', token: b.access)).json['mutual'] as List).single['id'] as String;

        final set = await app.patch('/v1/contacts/$bId/preference', {'preference': 'ratherAvoid'}, token: a.access);
        expect(set.status, 200);
        expect((set.json['contacts'] as List).single['preference'], 'ratherAvoid');

        // B never learns A's preference.
        final bView = await app.get('/v1/dashboard', token: b.access);
        expect(bView.raw, isNot(contains('ratherAvoid')));
        expect((bView.json['contacts'] as List).single['preference'], 'neutral');
        expect(aId, isNot(bId));

        for (final bad in <Object?>[
          {'preference': 'hate'},
          {'preference': 7},
          {'preference': null},
          <String, Object?>{},
        ]) {
          final r = await app.patch('/v1/contacts/$bId/preference', bad, token: a.access);
          expect(r.status, 400, reason: '$bad');
          expect(r.code, 'validation_error');
        }

        // Cannot probe arbitrary user ids: only contacts in your own address book.
        final strangerId = (await repo.findUserByEmail(stranger.email))!.id;
        for (final id in [strangerId, 'u_doesnotexist']) {
          final r = await app.patch('/v1/contacts/$id/preference', {'preference': 'neutral'}, token: a.access);
          expect(r.status, 404, reason: id);
          expect(r.code, 'not_found');
        }
      });

      test('re-importing replaces the previous address book', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        await app.importContacts(a, [TestApp.contact('B', phones: [b.phone])]);
        await app.importContacts(a, [TestApp.contact('Nobody', phones: ['+14155550001'])]);
        final matches = (await app.get('/v1/contacts/matches', token: a.access)).json;
        expect(matches['oneWay'], isEmpty);
        expect(matches['notOnApp'], [
          {'name': 'Nobody', 'status': 'notOnApp'},
        ]);
      });

      test('only HMACs and display names are stored for imported contacts', () async {
        final a = await app.verifiedUser(1);
        await app.importContacts(a, [
          TestApp.contact('Pat Example', phones: ['(415) 555-7777'], emails: ['Pat@Example.test']),
        ]);
        final user = (await repo.findUserByEmail(a.email))!;
        final stored = await repo.contactsOf(user.id);
        expect(stored, hasLength(2));
        for (final record in stored) {
          expect(record.name, 'Pat Example');
          expect(record.identifierHash, matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(record.identifierHash, isNot(contains('555')));
        }
        final hmacs = Hmacs(testPepper);
        expect(stored.map((r) => r.identifierHash), containsAll([hmacs.phone('+14155557777'), hmacs.email('pat@example.test')]));
      });
    });

    group('account export and deletion', () {
      test('export contains the user own data and nothing about other users', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        await app.importContacts(a, [TestApp.contact('Bee', phones: [b.phone])]);
        await app.importContacts(b, [TestApp.contact('Aay', phones: [a.phone])]);
        final bId = ((await app.get('/v1/contacts/matches', token: a.access)).json['mutual'] as List).single['id'] as String;
        await app.patch('/v1/contacts/$bId/preference', {'preference': 'loveToSee'}, token: a.access);

        final r = await app.get('/v1/account/export', token: a.access);
        expect(r.status, 200, reason: r.raw);
        expect(r.json['profile']['email'], a.email);
        expect(r.json['profile']['phoneVerified'], isTrue);
        expect((r.json['contacts'] as List).single['name'], 'Bee');
        expect((r.json['preferences'] as List).single, {'contactId': bId, 'preference': 'loveToSee'});
        expect(r.raw, isNot(contains(b.email)));
        expect(r.raw, isNot(contains(b.phone)));
        expect(r.raw, isNot(contains('passwordHash')));
        expect(r.raw, isNot(contains('argon2')));
        expect(r.json['exportedAt'], isA<String>());
      });

      test('delete requires the correct password', () async {
        final s = await app.signUp(1);
        expect((await app.call('DELETE', '/v1/account', token: s.access)).status, 400);
        expect((await app.call('DELETE', '/v1/account', body: {'password': 5}, token: s.access)).status, 400);
        final wrong = await app.call('DELETE', '/v1/account', body: {'password': 'wrong-password-9'}, token: s.access);
        expect(wrong.status, 401);
        expect(wrong.code, 'invalid_credentials');
        expect((await app.get('/v1/dashboard', token: s.access)).status, 200, reason: 'account untouched');
      });

      test('delete hard-deletes the user and everything about them', () async {
        final a = await app.verifiedUser(1);
        final b = await app.verifiedUser(2);
        await app.importContacts(a, [TestApp.contact('Bee', phones: [b.phone])]);
        await app.importContacts(b, [TestApp.contact('Aay', phones: [a.phone])]);
        final bId = ((await app.get('/v1/contacts/matches', token: a.access)).json['mutual'] as List).single['id'] as String;
        final aId = ((await app.get('/v1/contacts/matches', token: b.access)).json['mutual'] as List).single['id'] as String;
        await app.patch('/v1/contacts/$bId/preference', {'preference': 'loveToSee'}, token: a.access);
        await app.patch('/v1/contacts/$aId/preference', {'preference': 'ratherAvoid'}, token: b.access);
        final other = await app.post('/v1/auth/login', {'email': a.email, 'password': a.password});

        final r = await app.call('DELETE', '/v1/account', body: {'password': a.password}, token: a.access);
        expect(r.status, 200, reason: r.raw);
        expect(r.json, {'ok': true});

        expect(await repo.findUserByEmail(a.email), isNull);
        expect(await repo.findUserById(aId), isNull);
        expect(await repo.contactsOf(aId), isEmpty);
        expect(await repo.preferencesOf(aId), isEmpty);
        expect(await repo.preferencesOf((await repo.findUserByEmail(b.email))!.id), isNot(contains(aId)));
        expect(await repo.listSessions(aId), isEmpty);
        expect(await repo.findAccessToken(hashToken(a.access)), isNull);
        expect(await repo.findRefreshToken(hashToken(a.refresh)), isNull);
        expect(await repo.findVerificationCode(VerificationPurpose.phoneVerify, a.phone), isNull);

        expect((await app.get('/v1/dashboard', token: a.access)).status, 401);
        expect((await app.get('/v1/dashboard', token: other.json['accessToken'] as String)).status, 401);
        expect((await app.post('/v1/auth/login', {'email': a.email, 'password': a.password})).code, 'invalid_credentials');

        // B no longer sees A, and the identifiers can be registered again.
        final matches = (await app.get('/v1/contacts/matches', token: b.access)).json;
        expect(matches['mutual'], isEmpty);
        expect(matches['oneWay'], isEmpty);
        expect((await app.signUp(1)).access, isNotEmpty);
      });
    });

    group('rate limiting', () {
      late TestApp strict;

      setUp(() {
        strict = TestApp(repo, rateLimits: const RateLimitConfig());
      });

      test('login: 5 per minute per IP, with Retry-After', () async {
        final s = await strict.signUp(1);
        for (var i = 0; i < 5; i++) {
          final r = await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password});
          expect(r.status, 200);
        }
        final limited = await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password});
        expect(limited.status, 429);
        expect(limited.code, 'rate_limited');
        expect(limited.json['retryAfterSeconds'], isA<int>());
        expect(limited.json['retryAfterSeconds'], greaterThan(0));
        expect(limited.headers['retry-after'], '${limited.json['retryAfterSeconds']}');
        expect(limited.json['requestId'], isNotEmpty);

        // A different IP is unaffected; the same IP recovers after the window.
        expect((await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password}, ip: '10.9.9.9')).status, 200);
        strict.clock.advance(const Duration(seconds: 61));
        expect((await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password})).status, 200);
      });

      test('login: repeated failures lock the account out, even from new IPs, with exponential backoff', () async {
        final s = await strict.signUp(1);
        for (var i = 0; i < 5; i++) {
          final r = await strict.post('/v1/auth/login', {'email': s.email, 'password': 'wrong-password-$i'}, ip: '10.1.0.$i');
          expect(r.status, 401);
        }
        final locked = await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password}, ip: '10.1.0.99');
        expect(locked.status, 429, reason: 'correct password is also refused while locked');
        expect(locked.code, 'rate_limited');
        expect(locked.headers['retry-after'], isNotNull);

        strict.clock.advance(const Duration(seconds: 16));
        // Next failure doubles the lockout (30s).
        expect((await strict.post('/v1/auth/login', {'email': s.email, 'password': 'wrong-password-x'}, ip: '10.1.1.1')).status, 401);
        strict.clock.advance(const Duration(seconds: 20));
        expect((await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password}, ip: '10.1.1.2')).status, 429);
        strict.clock.advance(const Duration(seconds: 15));
        expect((await strict.post('/v1/auth/login', {'email': s.email, 'password': s.password}, ip: '10.1.1.3')).status, 200);
      });

      test('lockout applies to unknown emails the same way (no account oracle)', () async {
        for (var i = 0; i < 5; i++) {
          await strict.post('/v1/auth/login', {'email': 'ghost@example.test', 'password': 'wrong-password-1'}, ip: '10.2.0.$i');
        }
        final r = await strict.post('/v1/auth/login', {'email': 'ghost@example.test', 'password': 'wrong-password-1'}, ip: '10.2.0.99');
        expect(r.status, 429);
      });

      test('signup: 5 per hour per IP', () async {
        for (var i = 0; i < 5; i++) {
          final r = await strict.post('/v1/auth/signup', {
            'email': TestApp.emailFor(i),
            'phone': TestApp.phoneFor(i),
            'password': strongPassword,
          });
          expect(r.status, 200);
        }
        final limited = await strict.post('/v1/auth/signup', {
          'email': TestApp.emailFor(9),
          'phone': TestApp.phoneFor(9),
          'password': strongPassword,
        });
        expect(limited.status, 429);
        expect(limited.headers['retry-after'], isNotNull);
        strict.clock.advance(const Duration(hours: 1, seconds: 1));
        expect(
          (await strict.post('/v1/auth/signup', {
            'email': TestApp.emailFor(9),
            'phone': TestApp.phoneFor(9),
            'password': strongPassword,
          }))
              .status,
          200,
        );
      });

      test('OTP sends: 3 per hour per destination', () async {
        final s = await strict.signUp(1);
        for (var i = 0; i < 3; i++) {
          expect((await strict.post('/v1/auth/verify/phone/send', {}, token: s.access)).status, 200);
        }
        final limited = await strict.post('/v1/auth/verify/phone/send', {}, token: s.access);
        expect(limited.status, 429);
        expect(limited.code, 'rate_limited');
        expect(strict.provider.sendsTo(s.phone), 4, reason: 'signup + 3 sends; the 4th request sent nothing');

        // Email destination has its own budget; password reset shares the email budget.
        for (var i = 0; i < 3; i++) {
          expect((await strict.post('/v1/auth/password-reset/request', {'email': s.email})).status, 200);
        }
        expect((await strict.post('/v1/auth/password-reset/request', {'email': s.email})).status, 429);
        strict.clock.advance(const Duration(hours: 1, seconds: 1));
        final refreshed = await strict.post('/v1/auth/refresh', {'refreshToken': s.refresh});
        final fresh = refreshed.json['accessToken'] as String;
        expect((await strict.post('/v1/auth/verify/phone/send', {}, token: fresh)).status, 200);
      });

      test('general API: per-user limit applies to authenticated routes', () async {
        final tight = TestApp(repo, rateLimits: const RateLimitConfig(apiPerUserPerMinute: 3));
        final s = await tight.signUp(1);
        for (var i = 0; i < 3; i++) {
          expect((await tight.get('/v1/dashboard', token: s.access)).status, 200);
        }
        final limited = await tight.get('/v1/dashboard', token: s.access);
        expect(limited.status, 429);
        expect(limited.headers['retry-after'], isNotNull);
        tight.clock.advance(const Duration(seconds: 61));
        expect((await tight.get('/v1/dashboard', token: s.access)).status, 200);
      });

      test('general API: per-IP limit applies before routing', () async {
        final tight = TestApp(repo, rateLimits: const RateLimitConfig(apiPerIpPerMinute: 3));
        for (var i = 0; i < 3; i++) {
          expect((await tight.get('/v1/nope')).status, 404);
        }
        expect((await tight.get('/v1/nope')).status, 429);
        expect((await tight.get('/health')).status, 200, reason: 'probes are exempt');
      });
    });
  });
}

class _CountingHasher extends PasswordHasher {
  _CountingHasher() : super(params: Argon2Params.fast);
  int verifies = 0;

  @override
  Future<bool> verify(String password, String encoded) {
    verifies++;
    return super.verify(password, encoded);
  }
}

/// Reports the database as unreachable; any other call fails.
class _UnreachableRepository extends _ThrowingRepository {
  @override
  Future<bool> ping() async => false;
}

class _ThrowingRepository implements Repository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('secret db detail');
}
