import 'package:reconnect_backend/auth/tokens.dart';
import 'package:reconnect_backend/db/memory_repository.dart';
import 'package:reconnect_backend/errors.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Service-level tests for refresh token rotation and reuse detection.
void main() {
  late MemoryRepository repo;
  late TestApp app;

  setUp(() {
    repo = MemoryRepository();
    app = TestApp(repo);
  });

  Matcher apiError(String code) => throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

  test('every refresh yields a new pair and invalidates the previous refresh token', () async {
    final s = await app.signUp(1);
    final auth = app.ctx.auth;
    final seen = <String>{s.refresh};
    var current = s.refresh;
    final retired = <String>[];
    for (var i = 0; i < 5; i++) {
      final next = await auth.refresh(current);
      expect(seen.add(next.refreshToken), isTrue, reason: 'refresh token never repeats');
      retired.add(current);
      current = next.refreshToken;
    }
    // The newest token still works; replaying any retired one is detected.
    await expectLater(auth.refresh(retired[2]), apiError('refresh_token_reused'));
    await expectLater(auth.refresh(current), apiError('invalid_refresh_token'), reason: 'family revoked');
  });

  test('presenting ANY earlier generation revokes the family, not just the previous one', () async {
    final s = await app.signUp(1);
    final auth = app.ctx.auth;
    final gen2 = await auth.refresh(s.refresh);
    final gen3 = await auth.refresh(gen2.refreshToken);
    final gen4 = await auth.refresh(gen3.refreshToken);

    await expectLater(auth.refresh(s.refresh), apiError('refresh_token_reused'));
    await expectLater(auth.refresh(gen4.refreshToken), apiError('invalid_refresh_token'));
    await expectLater(auth.authenticate(gen4.accessToken), apiError('invalid_access_token'));
  });

  test('concurrent use of one refresh token lets exactly one caller win', () async {
    final s = await app.signUp(1);
    final auth = app.ctx.auth;
    final results = await Future.wait([
      auth.refresh(s.refresh).then<Object>((t) => t, onError: (Object e) => e),
      auth.refresh(s.refresh).then<Object>((t) => t, onError: (Object e) => e),
    ]);
    final failures = results.whereType<ApiException>().toList();
    expect(failures, hasLength(1));
    expect(failures.single.code, 'refresh_token_reused');
  });

  test('sessions are independent: reuse on one device leaves the others alone', () async {
    final s = await app.signUp(1);
    final auth = app.ctx.auth;
    final phone = await auth.login(email: s.email, password: s.password, deviceLabel: 'phone');
    final laptop = await auth.login(email: s.email, password: s.password, deviceLabel: 'laptop');

    await auth.refresh(phone.tokens.refreshToken);
    await expectLater(auth.refresh(phone.tokens.refreshToken), apiError('refresh_token_reused'));

    expect((await auth.authenticate(laptop.tokens.accessToken)).user.email, s.email);
    expect((await auth.refresh(laptop.tokens.refreshToken)).accessToken, isNotEmpty);
    expect((await repo.listSessions(phone.user.id)).map((x) => x.deviceLabel), contains('laptop'));
  });

  test('access tokens and refresh tokens are not interchangeable', () async {
    final s = await app.signUp(1);
    await expectLater(app.ctx.auth.refresh(s.access), apiError('invalid_refresh_token'));
    await expectLater(app.ctx.auth.authenticate(s.refresh), apiError('invalid_access_token'));
  });

  test('only SHA-256 digests are persisted', () async {
    final s = await app.signUp(1);
    final lookup = (await repo.findAccessToken(hashToken(s.access)))!;
    expect(lookup.token.tokenHash, hashToken(s.access));
    expect(lookup.token.tokenHash, isNot(s.access));
    expect(lookup.token.tokenHash, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('purgeExpired removes dead tokens and sessions but keeps live ones', () async {
    final live = await app.signUp(1);
    final dead = await app.signUp(2);
    app.clock.advance(const Duration(days: 31));
    // Keep user 1 alive by refreshing at day 31 is impossible (expired); re-login instead.
    final relogin = await app.ctx.auth.login(email: live.email, password: live.password);
    final removed = await repo.purgeExpired(app.clock.now);
    expect(removed, greaterThan(0));
    expect(await repo.findRefreshToken(hashToken(dead.refresh)), isNull);
    expect(await repo.findRefreshToken(hashToken(relogin.tokens.refreshToken)), isNotNull);
  });
}
