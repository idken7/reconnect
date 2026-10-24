import 'package:reconnect_backend/db/repository.dart';
import 'package:reconnect_backend/models.dart';
import 'package:test/test.dart';

import 'api_suite.dart';

/// Behaviour every [Repository] implementation must share.
void defineRepositoryContract(String label, RepoFactory create) {
  group('Repository contract ($label)', () {
    late Repository repo;
    final t0 = DateTime.utc(2026, 1, 1, 12);
    var n = 0;

    User user(String key, {bool phoneVerified = true, bool emailVerified = false}) => User(
          id: 'u_$key',
          email: '$key@example.test',
          emailHash: 'eh_$key',
          emailVerifiedAt: emailVerified ? t0 : null,
          phone: '+1415555${1000 + n}',
          phoneHash: 'ph_$key',
          phoneVerifiedAt: phoneVerified ? t0 : null,
          passwordHash: 'hash_$key',
          name: key,
          homeCity: 'Brooklyn',
          currentLocation: 'Brooklyn',
          createdAt: t0,
        );

    Future<User> add(String key, {bool phoneVerified = true, bool emailVerified = false}) async {
      n++;
      final u = user(key, phoneVerified: phoneVerified, emailVerified: emailVerified);
      await repo.createUser(u);
      return u;
    }

    setUp(() async {
      repo = await create();
    });

    test('ping', () async => expect(await repo.ping(), isTrue));

    group('users', () {
      test('create and find, with timestamps preserved', () async {
        final u = await add('alice', emailVerified: true);
        final byId = (await repo.findUserById(u.id))!;
        expect(byId.email, u.email);
        expect(byId.phone, u.phone);
        expect(byId.phoneHash, 'ph_alice');
        expect(byId.phoneVerifiedAt, t0);
        expect(byId.emailVerifiedAt, t0);
        expect(byId.createdAt, t0);
        expect(byId.locationShared, isFalse);
        expect(byId.currentLocation, 'Brooklyn');
        expect((await repo.findUserByEmail(u.email))!.id, u.id);
        expect(await repo.findUserById('missing'), isNull);
        expect(await repo.findUserByEmail('missing@example.test'), isNull);
      });

      test('email and phone are unique', () async {
        final u = await add('alice');
        final sameEmail = User(
          id: 'u_other',
          email: u.email,
          emailHash: 'x',
          phone: '+14155559999',
          phoneHash: 'y',
          passwordHash: 'h',
          createdAt: t0,
        );
        await expectLater(repo.createUser(sameEmail), throwsA(isA<DuplicateUserException>()));
        final samePhone = User(
          id: 'u_other2',
          email: 'other@example.test',
          emailHash: 'x',
          phone: u.phone,
          phoneHash: 'y',
          passwordHash: 'h',
          createdAt: t0,
        );
        await expectLater(repo.createUser(samePhone), throwsA(isA<DuplicateUserException>()));
      });

      test('updateUser changes only the given fields', () async {
        final u = await add('alice');
        final updated = await repo.updateUser(u.id, bio: 'hello', locationShared: true, currentLocation: 'Austin');
        expect(updated.bio, 'hello');
        expect(updated.locationShared, isTrue);
        expect(updated.currentLocation, 'Austin');
        expect(updated.name, 'alice');
        expect(updated.homeCity, 'Brooklyn');
        final again = await repo.updateUser(u.id, profileImageUrl: 'https://x.test/a.png', name: 'Al', homeCity: 'Chicago');
        expect(again.bio, 'hello');
        expect(again.profileImageUrl, 'https://x.test/a.png');
        expect(again.name, 'Al');
        expect(again.homeCity, 'Chicago');
        expect((await repo.findUserById(u.id))!.locationShared, isTrue);
        final off = await repo.updateUser(u.id, locationShared: false);
        expect(off.locationShared, isFalse);
      });

      test('password hash, verification and last active', () async {
        final u = await add('alice', phoneVerified: false);
        await repo.setPasswordHash(u.id, 'new_hash');
        await repo.markVerified(u.id, IdentifierKind.phone, t0);
        await repo.markVerified(u.id, IdentifierKind.email, t0);
        await repo.markVerified(u.id, IdentifierKind.email, t0.add(const Duration(days: 1)));
        await repo.touchLastActive(u.id, t0.add(const Duration(hours: 2)));
        final loaded = (await repo.findUserById(u.id))!;
        expect(loaded.passwordHash, 'new_hash');
        expect(loaded.phoneVerifiedAt, t0);
        expect(loaded.emailVerifiedAt, t0, reason: 'first verification time is kept');
        expect(loaded.lastActiveAt, t0.add(const Duration(hours: 2)));
      });
    });

    group('sessions and tokens', () {
      SessionToken token(String id, String sessionId, TokenKind kind, String hash, {DateTime? expires}) => SessionToken(
            id: id,
            sessionId: sessionId,
            kind: kind,
            tokenHash: hash,
            expiresAt: expires ?? t0.add(const Duration(days: 30)),
          );

      test('access and refresh lookups by hash', () async {
        final u = await add('alice');
        final session = AuthSession(id: 's1', userId: u.id, deviceLabel: 'iPhone', createdAt: t0);
        await repo.createSession(session, [
          token('t1', 's1', TokenKind.access, 'acc_hash', expires: t0.add(const Duration(minutes: 15))),
          token('t2', 's1', TokenKind.refresh, 'ref_hash'),
        ]);

        final access = (await repo.findAccessToken('acc_hash'))!;
        expect(access.user.id, u.id);
        expect(access.session.id, 's1');
        expect(access.session.deviceLabel, 'iPhone');
        expect(access.token.expiresAt, t0.add(const Duration(minutes: 15)));
        expect(access.token.rotatedAt, isNull);
        expect(await repo.findAccessToken('ref_hash'), isNull, reason: 'kinds are not interchangeable');

        final refresh = (await repo.findRefreshToken('ref_hash'))!;
        expect(refresh.session.userId, u.id);
        expect(refresh.token.kind, TokenKind.refresh);
        expect(await repo.findRefreshToken('acc_hash'), isNull);
        expect(await repo.findAccessToken('nope'), isNull);
      });

      test('markRefreshRotated succeeds exactly once', () async {
        final u = await add('alice');
        await repo.createSession(AuthSession(id: 's1', userId: u.id, deviceLabel: '', createdAt: t0), [
          token('t2', 's1', TokenKind.refresh, 'ref_hash'),
        ]);
        expect(await repo.markRefreshRotated('t2', t0), isTrue);
        expect(await repo.markRefreshRotated('t2', t0), isFalse);
        expect((await repo.findRefreshToken('ref_hash'))!.token.rotatedAt, t0);
        await repo.addTokens([token('t3', 's1', TokenKind.refresh, 'ref_hash2')]);
        expect(await repo.findRefreshToken('ref_hash2'), isNotNull);
      });

      test('revokeSession hides access tokens but keeps refresh lookups for reuse detection', () async {
        final u = await add('alice');
        await repo.createSession(AuthSession(id: 's1', userId: u.id, deviceLabel: '', createdAt: t0), [
          token('t1', 's1', TokenKind.access, 'acc'),
          token('t2', 's1', TokenKind.refresh, 'ref'),
        ]);
        await repo.createSession(AuthSession(id: 's2', userId: u.id, deviceLabel: '', createdAt: t0), [
          token('t3', 's2', TokenKind.access, 'acc2'),
        ]);
        await repo.revokeSession('s1', t0);
        expect(await repo.findAccessToken('acc'), isNull);
        expect((await repo.findRefreshToken('ref'))!.session.revokedAt, t0);
        expect(await repo.findAccessToken('acc2'), isNotNull);
        expect((await repo.listSessions(u.id)).map((s) => s.id), ['s2']);

        await repo.revokeAllSessions(u.id, t0);
        expect(await repo.findAccessToken('acc2'), isNull);
        expect(await repo.listSessions(u.id), isEmpty);
      });

      test('purgeExpired removes expired tokens and orphaned sessions only', () async {
        final u = await add('alice');
        await repo.createSession(AuthSession(id: 'old', userId: u.id, deviceLabel: '', createdAt: t0), [
          token('o1', 'old', TokenKind.access, 'old_acc', expires: t0.add(const Duration(minutes: 15))),
          token('o2', 'old', TokenKind.refresh, 'old_ref', expires: t0.add(const Duration(days: 1))),
        ]);
        await repo.createSession(AuthSession(id: 'new', userId: u.id, deviceLabel: '', createdAt: t0), [
          token('n1', 'new', TokenKind.refresh, 'new_ref', expires: t0.add(const Duration(days: 30))),
        ]);
        final removed = await repo.purgeExpired(t0.add(const Duration(days: 2)));
        expect(removed, greaterThanOrEqualTo(3));
        expect(await repo.findRefreshToken('old_ref'), isNull);
        expect(await repo.findRefreshToken('new_ref'), isNotNull);
      });
    });

    group('verification codes', () {
      VerificationCode code(String id, {String? hash = 'h', DateTime? expires}) => VerificationCode(
            id: id,
            purpose: VerificationPurpose.phoneVerify,
            target: '+14155550100',
            codeHash: hash,
            expiresAt: expires ?? t0.add(const Duration(minutes: 10)),
            createdAt: t0,
          );

      test('one active code per purpose and target; attempts and consumption', () async {
        await repo.saveVerificationCode(code('c1'));
        await repo.saveVerificationCode(code('c2', hash: 'h2'));
        final found = (await repo.findVerificationCode(VerificationPurpose.phoneVerify, '+14155550100'))!;
        expect(found.id, 'c2');
        expect(found.codeHash, 'h2');
        expect(found.attempts, 0);
        expect(found.consumedAt, isNull);
        expect(found.expiresAt, t0.add(const Duration(minutes: 10)));
        expect(await repo.incrementCodeAttempts('c2'), 1);
        expect(await repo.incrementCodeAttempts('c2'), 2);
        await repo.consumeCode('c2', t0);
        final consumed = (await repo.findVerificationCode(VerificationPurpose.phoneVerify, '+14155550100'))!;
        expect(consumed.attempts, 2);
        expect(consumed.consumedAt, t0);
        expect(await repo.findVerificationCode(VerificationPurpose.emailVerify, '+14155550100'), isNull);
      });

      test('provider-held codes have no hash', () async {
        await repo.saveVerificationCode(code('c1', hash: null));
        expect((await repo.findVerificationCode(VerificationPurpose.phoneVerify, '+14155550100'))!.codeHash, isNull);
      });
    });

    group('contacts, matching primitives and preferences', () {
      ContactRecord record(int entry, String name, IdentifierKind kind, String hash) =>
          ContactRecord(entryIndex: entry, name: name, kind: kind, identifierHash: hash);

      test('replaceContacts replaces and de-duplicates by identifier hash', () async {
        final a = await add('alice');
        await repo.replaceContacts(a.id, [
          record(0, 'Bob', IdentifierKind.phone, 'ph_bob'),
          record(0, 'Bob', IdentifierKind.email, 'eh_bob'),
          record(1, 'Other Bob', IdentifierKind.phone, 'ph_bob'),
        ]);
        var stored = await repo.contactsOf(a.id);
        expect(stored.map((c) => c.identifierHash).toSet(), {'ph_bob', 'eh_bob'});
        expect(stored.firstWhere((c) => c.identifierHash == 'ph_bob').name, 'Bob');

        await repo.replaceContacts(a.id, [record(0, 'Carol', IdentifierKind.phone, 'ph_carol')]);
        stored = await repo.contactsOf(a.id);
        expect(stored.single.name, 'Carol');
        expect(stored.single.kind, IdentifierKind.phone);
        expect(stored.single.entryIndex, 0);
        await repo.replaceContacts(a.id, const []);
        expect(await repo.contactsOf(a.id), isEmpty);
      });

      test('large imports', () async {
        final a = await add('alice');
        await repo.replaceContacts(a.id, [
          for (var i = 0; i < 5000; i++) record(i, 'Contact $i', IdentifierKind.phone, 'ph_$i'),
        ]);
        expect(await repo.contactsOf(a.id), hasLength(5000));
      });

      test('findVerifiedUsersByHashes only returns verified identifiers of other users', () async {
        final me = await add('me');
        final both = await add('both', emailVerified: true);
        final phoneOnly = await add('phoneonly');
        final unverified = await add('unverified', phoneVerified: false);
        final hashes = {'ph_both', 'eh_both', 'ph_phoneonly', 'eh_phoneonly', 'ph_unverified', 'eh_unverified', 'ph_me'};
        final matches = await repo.findVerifiedUsersByHashes(hashes, excludeUserId: me.id);
        final byUser = <String, Set<String>>{};
        for (final m in matches) {
          byUser.putIfAbsent(m.user.id, () => {}).add(m.identifierHash);
        }
        expect(byUser[both.id], {'ph_both', 'eh_both'});
        expect(byUser[phoneOnly.id], {'ph_phoneonly'}, reason: 'email not verified');
        expect(byUser.containsKey(unverified.id), isFalse);
        expect(byUser.containsKey(me.id), isFalse);
        expect(await repo.findVerifiedUsersByHashes({}, excludeUserId: me.id), isEmpty);
      });

      test('usersHoldingAnyHash', () async {
        final a = await add('alice');
        final b = await add('bob');
        final c = await add('carol');
        await repo.replaceContacts(a.id, [record(0, 'x', IdentifierKind.phone, 'ph_me')]);
        await repo.replaceContacts(b.id, [record(0, 'x', IdentifierKind.phone, 'ph_other')]);
        final holders = await repo.usersHoldingAnyHash({a.id, b.id, c.id}, {'ph_me', 'eh_me'});
        expect(holders, {a.id});
        expect(await repo.usersHoldingAnyHash({}, {'ph_me'}), isEmpty);
        expect(await repo.usersHoldingAnyHash({a.id}, {}), isEmpty);
      });

      test('preferences are per viewer and upserted', () async {
        final a = await add('alice');
        final b = await add('bob');
        await repo.setPreference(a.id, b.id, 'loveToSee');
        await repo.setPreference(a.id, b.id, 'ratherAvoid');
        expect(await repo.preferencesOf(a.id), {b.id: 'ratherAvoid'});
        expect(await repo.preferencesOf(b.id), isEmpty);
      });
    });

    group('deleteUser', () {
      test('removes the user and every row that references them', () async {
        final a = await add('alice');
        final b = await add('bob');
        await repo.createSession(AuthSession(id: 'sa', userId: a.id, deviceLabel: '', createdAt: t0), [
          SessionToken(
            id: 'ta',
            sessionId: 'sa',
            kind: TokenKind.access,
            tokenHash: 'a_acc',
            expiresAt: t0.add(const Duration(days: 1)),
          ),
        ]);
        await repo.createSession(AuthSession(id: 'sb', userId: b.id, deviceLabel: '', createdAt: t0), [
          SessionToken(
            id: 'tb',
            sessionId: 'sb',
            kind: TokenKind.access,
            tokenHash: 'b_acc',
            expiresAt: t0.add(const Duration(days: 1)),
          ),
        ]);
        await repo.saveVerificationCode(VerificationCode(
          id: 'vc',
          purpose: VerificationPurpose.passwordReset,
          target: a.email,
          userId: a.id,
          codeHash: 'h',
          expiresAt: t0.add(const Duration(minutes: 10)),
          createdAt: t0,
        ));
        await repo.replaceContacts(a.id, [const ContactRecord(entryIndex: 0, name: 'Bob', kind: IdentifierKind.phone, identifierHash: 'ph_bob')]);
        await repo.replaceContacts(b.id, [const ContactRecord(entryIndex: 0, name: 'Alice', kind: IdentifierKind.phone, identifierHash: 'ph_alice')]);
        await repo.setPreference(a.id, b.id, 'loveToSee');
        await repo.setPreference(b.id, a.id, 'ratherAvoid');

        await repo.deleteUser(a.id);

        expect(await repo.findUserById(a.id), isNull);
        expect(await repo.findAccessToken('a_acc'), isNull);
        expect(await repo.listSessions(a.id), isEmpty);
        expect(await repo.findVerificationCode(VerificationPurpose.passwordReset, a.email), isNull);
        expect(await repo.contactsOf(a.id), isEmpty);
        expect(await repo.preferencesOf(a.id), isEmpty);
        expect(await repo.preferencesOf(b.id), isEmpty, reason: 'preferences about the deleted user go too');
        // The other user is untouched.
        expect(await repo.findUserById(b.id), isNotNull);
        expect(await repo.findAccessToken('b_acc'), isNotNull);
        expect(await repo.contactsOf(b.id), hasLength(1));
        // Deleting twice is harmless.
        await repo.deleteUser(a.id);
      });
    });
  });
}
