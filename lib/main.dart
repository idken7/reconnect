import 'package:flutter/material.dart';

import 'app.dart';
import 'config/environment.dart';

void main() {
  // Release builds default to production; debug/profile default to dev.
  // Override with --dart-define=FLAVOR=dev|staging|prod and
  // --dart-define=RECONNECT_API_BASE_URL=https://... (see docs/RELEASE.md).
  EnvironmentService.setEnvironment(EnvironmentConfig.fromBuild());

  runApp(const ReconnectApp());
}
