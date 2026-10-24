#!/bin/bash

# Build Reconnect for TestFlight
# Usage: ./scripts/build_testflight.sh <VERSION> <BUILD_NUMBER>
# Example: ./scripts/build_testflight.sh 0.1.0 1
#
# Environment:
#   FLAVOR                   prod (default) or staging. "dev" is rejected: a release
#                            build must never point at localhost.
#   RECONNECT_API_BASE_URL   optional https URL overriding the flavor's default host.

set -e

VERSION=${1:-0.1.0}
BUILD_NUMBER=${2:-1}
FLAVOR=${FLAVOR:-prod}
if [[ "$FLAVOR" != "prod" && "$FLAVOR" != "staging" ]]; then
  echo "FLAVOR must be prod or staging for a release build (got '$FLAVOR')" >&2
  exit 1
fi
DART_DEFINES=(--dart-define=FLAVOR="$FLAVOR")
if [[ -n "${RECONNECT_API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define=RECONNECT_API_BASE_URL="$RECONNECT_API_BASE_URL")
fi
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🏗️  Building Reconnect for TestFlight"
echo "Version: $VERSION"
echo "Build Number: $BUILD_NUMBER"
echo "Flavor: $FLAVOR"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cd "$PROJECT_DIR"
flutter clean
rm -rf build/

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Update build number in pubspec.yaml if needed
echo "📝 Verifying version in pubspec.yaml..."
# Note: Version is in pubspec.yaml as 0.1.0+BUILD_NUMBER format

# Build for iOS Release (for TestFlight)
echo "🔨 Building iOS Release build..."
flutter build ios \
  --release \
  --no-tree-shake-icons \
  --build-name=$VERSION \
  --build-number=$BUILD_NUMBER \
  "${DART_DEFINES[@]}" \
  -v

echo ""
echo "✅ Build complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Select 'Runner' scheme"
echo "3. Select 'Generic iOS Device' as the target"
echo "4. Product → Archive"
echo "5. In Organizer, click 'Distribute App'"
echo "6. Select 'TestFlight'"
echo "7. Follow the wizard to upload"
echo ""
echo "Or use: ./scripts/upload_to_testflight.sh $VERSION $BUILD_NUMBER"
