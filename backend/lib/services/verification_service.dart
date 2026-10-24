import 'dart:math';

import '../auth/tokens.dart';
import '../config.dart';
import '../db/repository.dart';
import '../errors.dart';
import '../models.dart';
import '../util.dart';
import 'verification_provider.dart';

/// Issues and checks one-time codes: 6 digits, HMAC-hashed at rest, 10 minute
/// TTL (configurable) and a cap on wrong guesses per code.
class VerificationService {
  VerificationService({
    required this.repository,
    required this.provider,
    required this.hmacs,
    required AppConfig config,
    Clock clock = systemClock,
    this.maxAttempts = 5,
  })  : _clock = clock,
        _codeTtl = config.codeTtl,
        // The shortcut needs ALL of: non-production env, console provider
        // configured, and a console provider instance actually in use.
        allowTestCode = !config.isProduction &&
            config.verificationProvider == VerificationProviderKind.console &&
            provider is ConsoleVerificationProvider;

  static const String testCode = '000000';

  final Repository repository;
  final VerificationProvider provider;
  final Hmacs hmacs;
  final Clock _clock;
  final Duration _codeTtl;
  final int maxAttempts;
  final bool allowTestCode;
  final Random _random = Random.secure();

  static VerificationChannel channelFor(VerificationPurpose purpose) =>
      purpose == VerificationPurpose.phoneVerify ? VerificationChannel.sms : VerificationChannel.email;

  /// Creates a fresh code for [target] (replacing any previous one) and delivers it.
  /// Throws [VerificationDeliveryException] when the provider fails.
  Future<void> send(VerificationPurpose purpose, String target, {String? userId}) async {
    final now = _clock();
    final code = _random.nextInt(1000000).toString().padLeft(6, '0');
    await repository.saveVerificationCode(VerificationCode(
      id: newId('vc'),
      purpose: purpose,
      target: target,
      userId: userId,
      codeHash: provider.hostsCodes ? null : hmacs.code(purpose.wire, target, code),
      expiresAt: now.add(_codeTtl),
      createdAt: now,
    ));
    await provider.send(channel: channelFor(purpose), to: target, code: code);
  }

  /// Returns true (and consumes the code) when [code] is valid for [target].
  /// Throws a 400 when the code has been guessed wrong too often.
  Future<bool> check(VerificationPurpose purpose, String target, String code) async {
    if (allowTestCode && constantTimeEquals(code, testCode)) return true;

    final record = await repository.findVerificationCode(purpose, target);
    final now = _clock();
    if (record == null || record.consumedAt != null || !record.expiresAt.isAfter(now)) return false;
    if (record.attempts >= maxAttempts) {
      throw ApiException.validation('Too many incorrect attempts. Request a new code.');
    }

    final bool valid;
    if (provider.hostsCodes) {
      valid = await provider.check(channel: channelFor(purpose), to: target, code: code);
    } else {
      final expected = record.codeHash;
      valid = expected != null && constantTimeEquals(expected, hmacs.code(purpose.wire, target, code));
    }
    if (!valid) {
      await repository.incrementCodeAttempts(record.id);
      return false;
    }
    await repository.consumeCode(record.id, now);
    return true;
  }
}
