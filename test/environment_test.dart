import 'package:flutter_test/flutter_test.dart';
import 'package:reconnect/config/environment.dart';

void main() {
  group('EnvironmentConfig.resolve', () {
    test('release builds default to production', () {
      final config = EnvironmentConfig.resolve(flavor: '', apiBaseUrlOverride: '', isRelease: true);
      expect(config.isProduction, isTrue);
      expect(config.apiBaseUrl, kProductionApiBaseUrl);
      expect(config.apiBaseUrl, startsWith('https://'));
    });

    test('debug builds default to development', () {
      final config = EnvironmentConfig.resolve(flavor: '', apiBaseUrlOverride: '', isRelease: false);
      expect(config.isDevelopment, isTrue);
      expect(config.apiBaseUrl, anyOf('http://localhost:8080', 'http://10.0.2.2:8080'));
    });

    test('staging is not reported as production', () {
      final config = EnvironmentConfig.resolve(flavor: 'staging', apiBaseUrlOverride: '', isRelease: true);
      expect(config.isStaging, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.apiBaseUrl, kStagingApiBaseUrl);
      expect(EnvironmentConfig.staging().isProduction, isFalse);
    });

    test('an explicit flavor wins over build mode in debug', () {
      final config = EnvironmentConfig.resolve(flavor: 'prod', apiBaseUrlOverride: '', isRelease: false);
      expect(config.isProduction, isTrue);
    });

    test('RECONNECT_API_BASE_URL overrides the host', () {
      final config = EnvironmentConfig.resolve(
        flavor: 'staging',
        apiBaseUrlOverride: 'https://example.test/api/',
        isRelease: true,
      );
      expect(config.apiBaseUrl, 'https://example.test/api');
      expect(config.isStaging, isTrue);
    });

    test('release builds refuse the dev flavor', () {
      expect(
        () => EnvironmentConfig.resolve(flavor: 'dev', apiBaseUrlOverride: '', isRelease: true),
        throwsA(isA<EnvironmentConfigError>()),
      );
    });

    test('release builds refuse a non-https API URL', () {
      expect(
        () => EnvironmentConfig.resolve(flavor: 'prod', apiBaseUrlOverride: 'http://10.0.0.5:8080', isRelease: true),
        throwsA(isA<EnvironmentConfigError>()),
      );
    });

    test('debug builds accept a plain http override', () {
      final config = EnvironmentConfig.resolve(
        flavor: 'dev',
        apiBaseUrlOverride: 'http://192.168.1.20:8080',
        isRelease: false,
      );
      expect(config.apiBaseUrl, 'http://192.168.1.20:8080');
    });

    test('unknown flavors fail loudly', () {
      expect(
        () => EnvironmentConfig.resolve(flavor: 'qa', apiBaseUrlOverride: '', isRelease: false),
        throwsA(isA<EnvironmentConfigError>()),
      );
    });
  });
}
