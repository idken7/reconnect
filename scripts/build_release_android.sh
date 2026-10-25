#!/bin/bash

# Build a signed Android App Bundle (.aab) for Google Play.
# Usage: ./scripts/build_release_android.sh <VERSION> <BUILD_NUMBER>
# Example: ./scripts/build_release_android.sh 0.1.0 1
#
# Fails unless android/key.properties exists, so a store build can never be
# signed with the debug key. See docs/RELEASE.md for creating the keystore.
#
# Environment:
#   FLAVOR                   prod (default) or staging. "dev" is rejected.
#   RECONNECT_API_BASE_URL   optional https URL overriding the flavor's default host.

set -euo pipefail

VERSION=${1:-0.1.0}
BUILD_NUMBER=${2:-1}
FLAVOR=${FLAVOR:-prod}
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$FLAVOR" != "prod" && "$FLAVOR" != "staging" ]]; then
  echo "FLAVOR must be prod or staging for a release build (got '$FLAVOR')" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/android/key.properties" ]]; then
  echo "ERROR: android/key.properties not found." >&2
  echo "Create the upload keystore and key.properties first (see docs/RELEASE.md)." >&2
  exit 1
fi

DART_DEFINES=(--dart-define=FLAVOR="$FLAVOR")
if [[ -n "${RECONNECT_API_BASE_URL:-}" ]]; then
  DART_DEFINES+=(--dart-define=RECONNECT_API_BASE_URL="$RECONNECT_API_BASE_URL")
fi

# Makes Gradle itself refuse to fall back to the debug key.
export ORG_GRADLE_PROJECT_reconnectRequireReleaseKey=true

cd "$PROJECT_DIR"
echo "Building Reconnect $VERSION ($BUILD_NUMBER) for Android, flavor: $FLAVOR"
flutter pub get
flutter build appbundle \
  --release \
  --build-name="$VERSION" \
  --build-number="$BUILD_NUMBER" \
  --obfuscate \
  --split-debug-info=build/symbols/android \
  "${DART_DEFINES[@]}"

echo ""
echo "Bundle:  build/app/outputs/bundle/release/app-release.aab"
echo "Symbols: build/symbols/android (keep these to symbolicate crash reports)"
