import 'package:reconnect_backend/config.dart';
import 'package:reconnect_backend/db/memory_repository.dart';
import 'package:reconnect_backend/services/verification_provider.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

const _prodBase = {
  'ENV': 'production',
  'DATABASE_URL': 'postgres://user:pw@db.internal:5432/reconnect',
  'PEPPER': 'a-long-random-pepper-value-of-at-least-32-chars',
  'TWILIO_ACCOUNT_SID': 'ACxxxxxxxx',
  'TWILIO_AUTH_TOKEN': 'token',
  'TWILIO_VERIFY_SERVICE_SID': 'VAxxxxxxxx',
  'ALLOWED_ORIGINS': 'https://reconnect.example, https://www.reconnect.example/',
};

void main() {
  test('defaults suit local development', () {
    final config = AppConfig.fromEnv({});
    expect(config.env, AppEnv.development);
    expect(config.port, 8080);
    expect(config.host, '0.0.0.0');
    expect(config.databaseUrl, isNull);
    expect(config.verificationProvider, VerificationProviderKind.console);
    expect(config.allowedOrigins, isEmpty);
    expect(config.accessTokenTtl, const Duration(minutes: 15));
    expect(config.refreshTokenTtl, const Duration(days: 30));
    expect(config.codeTtl, const Duration(minutes: 10));
    expect(config.pepper.length, greaterThanOrEqualTo(32), reason: 'ephemeral random pepper');
    expect(config.allowTestCode, isTrue);
  });

  test('a complete production environment is accepted', () {
    final config = AppConfig.fromEnv({..._prodBase, 'PORT': '9000', 'TRUST_PROXY': 'true', 'ACCESS_TOKEN_TTL_SECONDS': '600'});
    expect(config.isProduction, isTrue);
    expect(config.port, 9000);
    expect(config.trustProxy, isTrue);
    expect(config.accessTokenTtl, const Duration(minutes: 10));
    expect(config.verificationProvider, VerificationProviderKind.twilio);
    expect(config.twilio!.verifyServiceSid, 'VAxxxxxxxx');
    expect(config.allowedOrigins, ['https://reconnect.example', 'https://www.reconnect.example']);
    expect(config.allowTestCode, isFalse);
  });

  test('production fails fast on every missing required value', () {
    for (final missing in ['DATABASE_URL', 'PEPPER', 'TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_VERIFY_SERVICE_SID']) {
      final env = {..._prodBase}..remove(missing);
      expect(() => AppConfig.fromEnv(env), throwsA(isA<ConfigException>()), reason: missing);
    }
    final all = <String, String>{'ENV': 'production'};
    try {
      AppConfig.fromEnv(all);
      fail('should throw');
    } on ConfigException catch (e) {
      expect(e.message, contains('DATABASE_URL'));
      expect(e.message, contains('PEPPER'));
      expect(e.message, contains('TWILIO'));
    }
  });

  test('rejects weak or unsafe production settings', () {
    expect(() => AppConfig.fromEnv({..._prodBase, 'PEPPER': 'short'}), throwsA(isA<ConfigException>()));
    expect(() => AppConfig.fromEnv({..._prodBase, 'VERIFICATION_PROVIDER': 'console'}), throwsA(isA<ConfigException>()));
    expect(() => AppConfig.fromEnv({..._prodBase, 'ALLOWED_ORIGINS': '*'}), throwsA(isA<ConfigException>()));
  });

  test('rejects malformed values', () {
    expect(() => AppConfig.fromEnv({'ENV': 'prod'}), throwsA(isA<ConfigException>()));
    expect(() => AppConfig.fromEnv({'PORT': 'abc'}), throwsA(isA<ConfigException>()));
    expect(() => AppConfig.fromEnv({'ACCESS_TOKEN_TTL_SECONDS': '0'}), throwsA(isA<ConfigException>()));
    expect(() => AppConfig.fromEnv({'VERIFICATION_PROVIDER': 'carrier-pigeon'}), throwsA(isA<ConfigException>()));
    expect(() => AppConfig.fromEnv({'VERIFICATION_PROVIDER': 'twilio'}), throwsA(isA<ConfigException>()));
  });

  test('a stable PEPPER is required whenever a database is configured', () {
    expect(() => AppConfig.fromEnv({'DATABASE_URL': 'postgres://localhost/db'}), throwsA(isA<ConfigException>()));
    AppConfig.fromEnv({'DATABASE_URL': 'postgres://localhost/db', 'PEPPER': 'x'});
  });

  group('the 000000 shortcut', () {
    test('only exists for non-production + console provider', () {
      expect(AppConfig(env: AppEnv.development, pepper: testPepper).allowTestCode, isTrue);
      expect(AppConfig(env: AppEnv.test, pepper: testPepper).allowTestCode, isTrue);
      expect(AppConfig(env: AppEnv.staging, pepper: testPepper).allowTestCode, isTrue);
      expect(AppConfig(env: AppEnv.production, pepper: testPepper).allowTestCode, isFalse);
      expect(
        AppConfig(env: AppEnv.staging, pepper: testPepper, verificationProvider: VerificationProviderKind.twilio)
            .allowTestCode,
        isFalse,
      );
    });

    test('is impossible in production even if the console provider is forced', () async {
      // Bypass fromEnv validation on purpose: the service itself must refuse.
      final prod = TestApp(MemoryRepository(), config: testConfig(env: AppEnv.production));
      expect(prod.ctx.verification.allowTestCode, isFalse);
      expect(prod.ctx.verification.provider, isA<ConsoleVerificationProvider>());
      final session = await prod.signUp(1);
      final attempt = await prod.post('/v1/auth/verify/phone/confirm', {'code': '000000'}, token: session.access);
      expect(attempt.status, 400);
      final reset = await prod.post('/v1/auth/password-reset/confirm', {
        'email': session.email,
        'code': '000000',
        'newPassword': 'a perfectly fine passphrase 9',
      });
      expect(reset.status, 400);
      final login = await prod.post('/v1/auth/login', {'email': session.email, 'password': session.password});
      expect(login.status, 200, reason: 'password untouched');
    });

    test('is impossible with a hosted provider outside production', () {
      final app = TestApp(
        MemoryRepository(),
        config: testConfig(provider: VerificationProviderKind.twilio),
      );
      expect(app.ctx.verification.allowTestCode, isFalse);
    });
  });
}
