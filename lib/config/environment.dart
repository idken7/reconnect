enum Environment {
  development,
  production,
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
  bool get isProduction => environment == Environment.production;

  factory EnvironmentConfig.development() {
    return const EnvironmentConfig(
      environment: Environment.development,
      apiBaseUrl: 'http://localhost:8080',
      apiTimeout: Duration(seconds: 30),
      enableLogging: true,
    );
  }

  factory EnvironmentConfig.production() {
    return const EnvironmentConfig(
      environment: Environment.production,
      apiBaseUrl: 'https://api.reconnect.example.com',
      apiTimeout: Duration(seconds: 30),
      enableLogging: false,
    );
  }

  factory EnvironmentConfig.staging() {
    return const EnvironmentConfig(
      environment: Environment.production,
      apiBaseUrl: 'https://staging-api.reconnect.example.com',
      apiTimeout: Duration(seconds: 30),
      enableLogging: true,
    );
  }
}

class EnvironmentService {
  static EnvironmentConfig _instance = EnvironmentConfig.development();

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
