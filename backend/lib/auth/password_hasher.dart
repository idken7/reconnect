import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/dart.dart';

import '../util.dart';

/// Argon2id parameters. Stored inside every hash (PHC string format) so they can
/// be raised later and old hashes upgraded on the next successful login.
class Argon2Params {
  const Argon2Params({this.memoryKiB = 19456, this.iterations = 2, this.parallelism = 1, this.hashLength = 32});

  /// OWASP minimum for Argon2id: 19 MiB, 2 iterations, 1 lane. Measured at
  /// roughly 50-170 ms per hash with the pure Dart implementation.
  static const Argon2Params production = Argon2Params();

  /// Cheap parameters for unit tests only.
  static const Argon2Params fast = Argon2Params(memoryKiB: 64, iterations: 1);

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;

  @override
  bool operator ==(Object other) =>
      other is Argon2Params &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism &&
      other.hashLength == hashLength;

  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism, hashLength);
}

/// Hashes and verifies passwords with salted Argon2id. The CPU heavy work runs
/// in a short-lived isolate so it never blocks the event loop, and at most
/// [maxConcurrent] hashes run at once to bound memory use.
class PasswordHasher {
  PasswordHasher({this.params = Argon2Params.production, int maxConcurrent = 2})
      : _permits = Semaphore(maxConcurrent);

  final Argon2Params params;
  final Semaphore _permits;

  static const String _prefix = r'$argon2id$v=19$';

  Future<String> hash(String password) {
    final p = params;
    return _permits.withPermit(() => Isolate.run(() => _hashSync(password, p)));
  }

  Future<bool> verify(String password, String encoded) {
    return _permits.withPermit(() => Isolate.run(() => _verifySync(password, encoded)));
  }

  /// True when [encoded] was produced with weaker/different parameters than the
  /// current ones (or is not an Argon2id hash at all).
  bool needsRehash(String encoded) {
    final parsed = _parse(encoded);
    return parsed == null || parsed.params != params;
  }

  static Future<String> _deriveEncoded(String password, Argon2Params p, List<int> salt) async {
    final key = await _algorithm(p).deriveKeyFromPassword(password: password, nonce: salt);
    final bytes = await key.extractBytes();
    return '$_prefix'
        'm=${p.memoryKiB},t=${p.iterations},p=${p.parallelism}\$'
        '${_b64(salt)}\$${_b64(bytes)}';
  }

  static DartArgon2id _algorithm(Argon2Params p) => DartArgon2id(
        memory: p.memoryKiB,
        parallelism: p.parallelism,
        iterations: p.iterations,
        hashLength: p.hashLength,
      );

  static Future<String> _hashSync(String password, Argon2Params p) {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    return _deriveEncoded(password, p, salt);
  }

  static Future<bool> _verifySync(String password, String encoded) async {
    final parsed = _parse(encoded);
    if (parsed == null) return false;
    final recomputed = await _deriveEncoded(password, parsed.params, parsed.salt);
    return constantTimeEquals(recomputed, encoded);
  }

  static ({Argon2Params params, List<int> salt})? _parse(String encoded) {
    if (!encoded.startsWith(_prefix)) return null;
    final parts = encoded.substring(_prefix.length).split(r'$');
    if (parts.length != 3) return null;
    final values = <String, int>{};
    for (final pair in parts[0].split(',')) {
      final kv = pair.split('=');
      if (kv.length != 2) return null;
      final number = int.tryParse(kv[1]);
      if (number == null) return null;
      values[kv[0]] = number;
    }
    final memory = values['m'];
    final iterations = values['t'];
    final lanes = values['p'];
    if (memory == null || iterations == null || lanes == null) return null;
    try {
      final salt = base64.decode(base64.normalize(parts[1]));
      final hashBytes = base64.decode(base64.normalize(parts[2]));
      return (
        params: Argon2Params(memoryKiB: memory, iterations: iterations, parallelism: lanes, hashLength: hashBytes.length),
        salt: salt,
      );
    } on FormatException {
      return null;
    }
  }

  static String _b64(List<int> bytes) => base64.encode(bytes).replaceAll('=', '');
}
