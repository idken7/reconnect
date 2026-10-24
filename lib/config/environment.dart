import 'package:flutter/foundation.dart';

enum Environment {
  development,
  staging,
  production,
}

/// Placeholder hosts. These MUST be replaced with the real deployed hosts
/// before a store release (see docs/RELEASE.md).
const String kProductionApiBaseUrl = 'https://api.reconnect.app';
const String kStagingApiBaseUrl = 'https://staging-api.reconnect.app';

/// Thrown at startup when the build configuration is unsafe (for example a
/// release build asking for the dev flavor or a plain-HTTP API URL).
class EnvironmentConfigError extends StateError {
  EnvironmentConfigError(super.message);
}

class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.apiTimeout,
    required this.enableLogging,
  });

  final Environment environment;
  final String apiBaseUrl;
  final Duration apiTimeout;
  final bool enableLogging;

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;

  factory EnvironmentConfig.development({String? apiBaseUrl}) {
    return EnvironmentConfig(
      environment: Environment.development,
      apiBaseUrl: apiBaseUrl ?? _defaultDevBaseUrl(),
      apiTimeout: const Duration(seconds: 30),
      enableLogging: true,
    );
  }

  factory EnvironmentConfig.production({String? apiBaseUrl}) {
    return EnvironmentConfig(
      environment: Environment.production,
      apiBaseUrl: apiBaseUrl ?? kProductionApiBaseUrl,
      apiTimeout: const Duration(seconds: 30),
      enableLogging: false,
    );
  }

  factory EnvironmentConfig.staging({String? apiBaseUrl}) {
    return EnvironmentConfig(
      environment: Environment.staging,
      apiBaseUrl: apiBaseUrl ?? kStagingApiBaseUrl,
      apiTimeout: const Duration(seconds: 30),
      enableLogging: true,
    );
  }

  /// Picks the configuration for this build.
  ///
  /// * [flavor] is the `--dart-define=FLAVOR=` value (`dev`, `staging`,
  ///   `prod`). When empty it is derived from [isRelease]: release builds are
  ///   production, everything else is development.
  /// * [apiBaseUrlOverride] is `--dart-define=RECONNECT_API_BASE_URL=`.
  ///
  /// Release builds refuse the `dev` flavor and any non-HTTPS API URL so a
  /// shipped binary can never talk to localhost or send tokens in clear text.
  factory EnvironmentConfig.resolve({
    required String flavor,
    required String apiBaseUrlOverride,
    required bool isRelease,
  }) {
    final trimmedFlavor = flavor.trim().toLowerCase();
    final override = apiBaseUrlOverride.trim();

    final effectiveFlavor = trimmedFlavor.isEmpty ? (isRelease ? 'prod' : 'dev') : trimmedFlavor;

    if (isRelease && effectiveFlavor == 'dev') {
      throw EnvironmentConfigError(
        'Release builds cannot use FLAVOR=dev. Pass FLAVOR=prod or FLAVOR=staging.',
      );
    }

    if (override.isNotEmpty) {
      final uri = Uri.tryParse(override);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw EnvironmentConfigError('RECONNECT_API_BASE_URL is not a valid URL: $override');
      }
      if (isRelease && uri.scheme != 'https') {
        throw EnvironmentConfigError('Release builds require an https RECONNECT_API_BASE_URL.');
      }
    }

    final baseUrl = override.isEmpty ? null : override.replaceFirst(RegExp(r'/+$'), '');

    switch (effectiveFlavor) {
      case 'prod':
        return EnvironmentConfig.production(apiBaseUrl: baseUrl);
      case 'staging':
        return EnvironmentConfig.staging(apiBaseUrl: baseUrl);
      case 'dev':
        return EnvironmentConfig.development(apiBaseUrl: baseUrl);
      default:
        throw EnvironmentConfigError('Unknown FLAVOR "$flavor". Use dev, staging or prod.');
    }
  }

  /// The configuration baked into this build via `--dart-define`.
  factory EnvironmentConfig.fromBuild() {
    return EnvironmentConfig.resolve(
      flavor: const String.fromEnvironment('FLAVOR'),
      apiBaseUrlOverride: const String.fromEnvironment('RECONNECT_API_BASE_URL'),
      isRelease: kReleaseMode,
    );
  }

  /// localhost works for the iOS simulator and desktop; the Android emulator
  /// reaches the host machine at 10.0.2.2.
  static String _defaultDevBaseUrl() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}

class EnvironmentService {
  static EnvironmentConfig _instance = EnvironmentConfig.fromBuild();

  static EnvironmentConfig get instance => _instance;

  static void setEnvironment(EnvironmentConfig config) {
    _instance = config;
  }

  static void setDevelopment() {
    _instance = EnvironmentConfig.development();
  }

  static void setProduction() {
    _instance = EnvironmentConfig.production();
  }

  static void setStaging() {
    _instance = EnvironmentConfig.staging();
  }
}
