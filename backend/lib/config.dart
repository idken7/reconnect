import 'dart:convert';
import 'dart:math';

/// Deployment environment. Anything other than [production] is considered
/// non-production for the purposes of developer conveniences.
enum AppEnv { development, test, staging, production }

enum VerificationProviderKind { console, twilio }

class ConfigException implements Exception {
  ConfigException(this.message);
  final String message;
  @override
  String toString() => 'ConfigException: $message';
}

class TwilioConfig {
  const TwilioConfig({
    required this.accountSid,
    required this.authToken,
    required this.verifyServiceSid,
  });

  final String accountSid;
  final String authToken;
  final String verifyServiceSid;
}

/// Immutable runtime configuration, normally built from environment variables
/// with [AppConfig.fromEnv].
class AppConfig {
  AppConfig({
    this.env = AppEnv.development,
    this.host = '0.0.0.0',
    this.port = 8080,
    this.databaseUrl,
    this.allowedOrigins = const <String>[],
    required this.pepper,
    this.accessTokenTtl = const Duration(minutes: 15),
    this.refreshTokenTtl = const Duration(days: 30),
    this.codeTtl = const Duration(minutes: 10),
    this.verificationProvider = VerificationProviderKind.console,
    this.twilio,
    this.trustProxy = false,
    this.migrationsDir = 'migrations',
    this.logLevel = 'info',
  });

  final AppEnv env;
  final String host;
  final int port;
  final String? databaseUrl;
  final List<String> allowedOrigins;

  /// Server secret used to HMAC contact identifiers and verification codes.
  final String pepper;
  final Duration accessTokenTtl;
  final Duration refreshTokenTtl;
  final Duration codeTtl;
  final VerificationProviderKind verificationProvider;
  final TwilioConfig? twilio;

  /// Whether to read the client IP from proxy headers (`Fly-Client-IP`,
  /// `X-Forwarded-For`). Only enable behind a proxy that sets them.
  final bool trustProxy;
  final String migrationsDir;
  final String logLevel;

  bool get isProduction => env == AppEnv.production;

  /// The `000000` verification shortcut. Impossible in production and with any
  /// provider other than the console one.
  bool get allowTestCode => !isProduction && verificationProvider == VerificationProviderKind.console;

  static const int minPepperLength = 32;

  /// Builds the configuration from [environment] (usually `Platform.environment`)
  /// and fails fast with a [ConfigException] listing every problem.
  factory AppConfig.fromEnv(Map<String, String> environment) {
    final problems = <String>[];
    String? read(String key) {
      final value = environment[key]?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    int readInt(String key, int fallback, {int min = 1}) {
      final raw = read(key);
      if (raw == null) return fallback;
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed < min) {
        problems.add('$key must be an integer >= $min (got "$raw").');
        return fallback;
      }
      return parsed;
    }

    final envRaw = (read('ENV') ?? 'development').toLowerCase();
    final env = AppEnv.values.where((e) => e.name == envRaw).firstOrNull;
    if (env == null) {
      problems.add('ENV must be one of ${AppEnv.values.map((e) => e.name).join(', ')} (got "$envRaw").');
    }
    final effectiveEnv = env ?? AppEnv.development;
    final production = effectiveEnv == AppEnv.production;

    final providerRaw = (read('VERIFICATION_PROVIDER') ?? (production ? 'twilio' : 'console')).toLowerCase();
    final provider = VerificationProviderKind.values.where((e) => e.name == providerRaw).firstOrNull;
    if (provider == null) {
      problems.add('VERIFICATION_PROVIDER must be "console" or "twilio" (got "$providerRaw").');
    }
    final effectiveProvider = provider ?? VerificationProviderKind.console;
    if (production && effectiveProvider == VerificationProviderKind.console) {
      problems.add('VERIFICATION_PROVIDER=console is not allowed when ENV=production.');
    }

    TwilioConfig? twilio;
    if (effectiveProvider == VerificationProviderKind.twilio) {
      final sid = read('TWILIO_ACCOUNT_SID');
      final token = read('TWILIO_AUTH_TOKEN');
      final service = read('TWILIO_VERIFY_SERVICE_SID');
      if (sid == null || token == null || service == null) {
        problems.add('TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_VERIFY_SERVICE_SID are required '
            'when VERIFICATION_PROVIDER=twilio.');
      } else {
        twilio = TwilioConfig(accountSid: sid, authToken: token, verifyServiceSid: service);
      }
    }

    final databaseUrl = read('DATABASE_URL');
    if (production && databaseUrl == null) {
      problems.add('DATABASE_URL is required when ENV=production.');
    }

    var pepper = read('PEPPER');
    if (pepper == null) {
      if (production || databaseUrl != null) {
        problems.add('PEPPER (>= $minPepperLength chars) is required when ENV=production or DATABASE_URL is set, '
            'because contact hashes must stay stable across restarts.');
        pepper = '';
      } else {
        // Ephemeral in-memory development run: a throwaway secret is fine.
        final random = Random.secure();
        pepper = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
      }
    } else if (pepper.length < minPepperLength && production) {
      problems.add('PEPPER must be at least $minPepperLength characters in production.');
    }

    final origins = (read('ALLOWED_ORIGINS') ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '*')
        .map((e) => e.endsWith('/') ? e.substring(0, e.length - 1) : e)
        .toList(growable: false);
    if ((read('ALLOWED_ORIGINS') ?? '').split(',').any((e) => e.trim() == '*')) {
      problems.add('ALLOWED_ORIGINS must list explicit origins; "*" is not supported.');
    }

    final config = AppConfig(
      env: effectiveEnv,
      host: read('HOST') ?? '0.0.0.0',
      port: readInt('PORT', 8080, min: 0),
      databaseUrl: databaseUrl,
      allowedOrigins: origins,
      pepper: pepper,
      accessTokenTtl: Duration(seconds: readInt('ACCESS_TOKEN_TTL_SECONDS', 900)),
      refreshTokenTtl: Duration(days: readInt('REFRESH_TOKEN_TTL_DAYS', 30)),
      codeTtl: Duration(minutes: readInt('CODE_TTL_MINUTES', 10)),
      verificationProvider: effectiveProvider,
      twilio: twilio,
      trustProxy: (read('TRUST_PROXY') ?? 'false').toLowerCase() == 'true',
      migrationsDir: read('MIGRATIONS_DIR') ?? 'migrations',
      logLevel: (read('LOG_LEVEL') ?? 'info').toLowerCase(),
    );

    if (problems.isNotEmpty) {
      throw ConfigException('Invalid configuration:\n - ${problems.join('\n - ')}');
    }
    return config;
  }
}
