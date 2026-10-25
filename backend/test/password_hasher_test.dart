import 'package:reconnect_backend/auth/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  final hasher = PasswordHasher(params: Argon2Params.fast);

  test('hashes with Argon2id, a random salt and the parameters in the string', () async {
    final a = await hasher.hash('correct horse battery staple');
    final b = await hasher.hash('correct horse battery staple');
    expect(a, startsWith(r'$argon2id$v=19$m=64,t=1,p=1$'));
    expect(a, isNot(b), reason: 'unique salts');
    expect(a, isNot(contains('correct horse')));
    expect(a.split(r'$'), hasLength(6));
  });

  test('verifies the right password and rejects wrong ones', () async {
    final hash = await hasher.hash('s3cret-passphrase');
    expect(await hasher.verify('s3cret-passphrase', hash), isTrue);
    expect(await hasher.verify('s3cret-passphrasE', hash), isFalse);
    expect(await hasher.verify('', hash), isFalse);
  });

  test('never throws on garbage stored hashes', () async {
    for (final junk in ['', 'plain', r'$argon2id$v=19$m=x,t=1,p=1$AAAA$BBBB', r'$argon2id$v=19$m=64,t=1,p=1$%%%$%%%', r'$2b$10$abc']) {
      expect(await hasher.verify('x', junk), isFalse, reason: junk);
    }
  });

  test('needsRehash detects weaker parameters and legacy hashes', () async {
    final weak = await hasher.hash('pw-pw-pw-pw');
    expect(hasher.needsRehash(weak), isFalse);
    final stronger = PasswordHasher(params: const Argon2Params(memoryKiB: 128, iterations: 2));
    expect(stronger.needsRehash(weak), isTrue);
    expect(stronger.needsRehash(await stronger.hash('pw-pw-pw-pw')), isFalse);
    // Old unsalted SHA-256 hashes (hex) always need replacing.
    expect(hasher.needsRehash('ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f'), isTrue);
    // A hash made with the old params still verifies under the new hasher until upgraded.
    expect(await stronger.verify('pw-pw-pw-pw', weak), isTrue);
  });

  test('production parameters are OWASP-grade and fast enough (< 500 ms)', () async {
    const params = Argon2Params.production;
    expect(params.memoryKiB, greaterThanOrEqualTo(19456));
    expect(params.iterations, greaterThanOrEqualTo(2));
    final production = PasswordHasher();
    final watch = Stopwatch()..start();
    final hash = await production.hash('benchmark-password');
    final hashMs = watch.elapsedMilliseconds;
    watch
      ..reset()
      ..start();
    expect(await production.verify('benchmark-password', hash), isTrue);
    final verifyMs = watch.elapsedMilliseconds;
    expect(hashMs, lessThan(500), reason: 'hash took ${hashMs}ms');
    expect(verifyMs, lessThan(500), reason: 'verify took ${verifyMs}ms');
  });
}
