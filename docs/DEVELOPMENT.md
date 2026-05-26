# Development Environment Setup

This guide covers setting up the Reconnect app for development and testing.

## Prerequisites

- **Flutter SDK**: 3.11.0 or higher
- **Xcode**: Latest version (for iOS development)
- **Cocoapods**: For iOS dependency management
- **Git**: For version control

Install Flutter: https://flutter.dev/docs/get-started/install

## Initial Setup

### 1. Clone and Dependencies

```bash
git clone <repository>
cd reconnect
flutter pub get
```

### 2. Install iOS Pods

```bash
cd ios
pod install
cd ..
```

### 3. Verify Setup

```bash
flutter doctor
```

All items should show a checkmark (✓)

## Running the App

### Development Mode

```bash
# Run with dev environment (localhost API)
flutter run

# Or use the helper script
./scripts/build_dev.sh
```

### Specific Device/Simulator

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run on iOS simulator
open -a Simulator
flutter run
```

## Testing

### Run All Tests

```bash
# Unit and widget tests
flutter test

# Or use helper script
./scripts/test.sh

# With coverage report
./scripts/test.sh --coverage
```

### Widget Tests

```bash
flutter test test/widget_test.dart
```

### Unit Tests

```bash
flutter test test/services/
```

### Integration Tests

```bash
# On device/simulator
flutter test integration_test/

# Or run specific integration test
flutter test integration_test/app_integration_test.dart
```

## Environment Configuration

The app supports multiple environments:

### Development (Default)

- **API**: `http://localhost:8080` (or `http://10.0.2.2:8080` on Android emulator)
- **Logging**: Enabled
- **Build**: Debug

```bash
flutter run  # Uses dev environment by default
```

### Production/TestFlight

- **API**: Production API URL
- **Logging**: Disabled
- **Build**: Release

```bash
./scripts/build_testflight.sh 0.1.0 1
```

### Custom API Endpoint

```bash
flutter run --dart-define=FLAVOR=dev \
  --dart-define=RECONNECT_API_BASE_URL=http://your-api.com
```

## Code Organization

```
lib/
├── main.dart              # Entry point and environment setup
├── app.dart               # Main app widget
├── models.dart            # Data models
├── app_state.dart         # Global app state
├── config/
│   └── environment.dart   # Environment configuration
├── screens/               # UI screens
├── services/
│   ├── backend/           # API client
│   ├── contacts/          # Contact import service
│   └── location/          # Location services
└── data/                  # Data sources and mock data

test/
├── widget_test.dart       # Widget tests
├── app_state_auth_refresh_test.dart  # App state tests
└── services/              # Service tests

integration_test/
└── app_integration_test.dart  # Full app integration tests
```

## Common Tasks

### Add New Dependency

```bash
flutter pub add package_name

# With specific version
flutter pub add package_name:^1.0.0
```

### Update All Dependencies

```bash
flutter pub upgrade
```

### Clean Build Cache

```bash
flutter clean
rm -rf pubspec.lock
flutter pub get
```

### Debug Issues

```bash
# Verbose output
flutter run -v

# Rebuild iOS pods
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Reset iOS build
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
```

## Hot Reload During Development

While running `flutter run`:

- Press `r` to hot reload (changes to Dart code)
- Press `R` to hot restart (if hot reload fails)
- Press `q` to quit

Hot reload is usually instant, but some changes require restart:

- Changes to widget state initialization
- Adding/removing methods or fields
- Changing method signatures

## Building for Distribution

See [TESTFLIGHT_SETUP.md](../docs/TESTFLIGHT_SETUP.md) for complete instructions on building for TestFlight.

Quick version:

```bash
./scripts/build_testflight.sh 0.1.0 1
# Then follow the prompts to upload
```

## Debugging

### Enable Debug Logging

The app has a debug mode in development:

```dart
// In lib/config/environment.dart
EnvironmentService.setEnvironment(
  EnvironmentConfig.development()
);
```

All API requests will be logged to console.

### Xcode Debugging

1. Open `ios/Runner.xcworkspace`
2. Select target device
3. Press Play button or Product → Run
4. Use Xcode debugger for breakpoints and stepping

### Flutter DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools

# Or built-in
flutter run
# Press 'd' to open DevTools
```

## Troubleshooting

**"Pod install" fails**
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
cd ..
```

**"Gradle build fails" (Android)**
```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter run
```

**"Xcode build fails"**
```bash
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
flutter run
```

## Next Steps

- Review [TESTFLIGHT_SETUP.md](../docs/TESTFLIGHT_SETUP.md) for TestFlight distribution
- Check [Testing](#testing) section for test examples
- Read Flutter docs: https://flutter.dev/docs
