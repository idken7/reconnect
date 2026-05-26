#!/bin/bash

# Upload Reconnect to TestFlight
# This script builds and uploads the app to TestFlight using Xcode's notarization
# Usage: ./scripts/upload_to_testflight.sh <VERSION> <BUILD_NUMBER>
# Example: ./scripts/upload_to_testflight.sh 0.1.0 1

set -e

VERSION=${1:-0.1.0}
BUILD_NUMBER=${2:-1}
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/ios/iphoneos"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive.xcarchive"

echo "📱 Preparing to upload Reconnect to TestFlight"
echo "Version: $VERSION"
echo "Build Number: $BUILD_NUMBER"
echo ""

# Step 1: Build iOS app
echo "🔨 Step 1: Building iOS app..."
cd "$PROJECT_DIR"
flutter build ios release \
  --no-tree-shake-icons \
  --build-name=$VERSION \
  --build-number=$BUILD_NUMBER

# Step 2: Create archive
echo ""
echo "📦 Step 2: Creating archive..."
cd "$PROJECT_DIR/ios"

xcodebuild archive \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$PROJECT_DIR/build/ios/derived" \
  -allowProvisioningUpdates

# Step 3: Export and upload
echo ""
echo "📤 Step 3: Preparing for upload..."
echo ""
echo "⚠️  To complete the upload, you can:"
echo ""
echo "Option A - Using Xcode Organizer (Manual):"
echo "  1. Open: open '$ARCHIVE_PATH'"
echo "  2. In Organizer, click 'Distribute App'"
echo "  3. Select 'TestFlight'"
echo "  4. Follow the wizard"
echo ""
echo "Option B - Using Transporter App (Recommended):"
echo "  1. Download: https://apps.apple.com/app/transporter/id1450874784"
echo "  2. Open Transporter"
echo "  3. Click '+' and select the archive at:"
echo "     $ARCHIVE_PATH"
echo "  4. Click 'Deliver'"
echo ""
echo "Option C - Using xcrun (Advanced):"
echo "  First, export the app using XCode's Organizer, then:"
echo "  xcrun altool --upload-app -f app.ipa --type ios -u <apple_id> -p <app_password>"
echo ""
echo "✅ Archive ready at: $ARCHIVE_PATH"
