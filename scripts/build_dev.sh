#!/bin/bash

# Quick build script for development testing
# Usage: ./scripts/build_dev.sh

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Building Reconnect for development..."
echo ""

cd "$PROJECT_DIR"

# Clean and get dependencies
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build with dev environment
echo "📦 Building for iOS (dev environment)..."
flutter build ios \
  --debug \
  -d "FLAVOR=dev" \
  -v

echo ""
echo "✅ Dev build complete!"
echo ""
echo "To run on device/simulator:"
echo "  flutter run"
echo ""
echo "To run specific device:"
echo "  flutter devices"
echo "  flutter run -d <device_id>"
