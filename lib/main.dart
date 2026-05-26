import 'package:flutter/material.dart';

import 'app.dart';
import 'config/environment.dart';

void main() {
  // Set the environment based on build configuration
  // For development: using localhost
  // For production/testflight: using production API
  final environment = _getEnvironmentFromFlavor();
  EnvironmentService.setEnvironment(environment);

  runApp(const ReconnectApp());
}

EnvironmentConfig _getEnvironmentFromFlavor() {
  // The build flavor is passed at compile time
  // For local development: flutter run
  // For TestFlight: flutter build ios --release (production)
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  
  switch (flavor) {
    case 'prod':
      return EnvironmentConfig.production();
    case 'staging':
      return EnvironmentConfig.staging();
    case 'dev':
    default:
      return EnvironmentConfig.development();
  }
}
