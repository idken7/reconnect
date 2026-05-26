#!/bin/bash

# Run all tests for the Reconnect app
# Usage: ./scripts/test.sh [--coverage]

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COVERAGE=false

if [[ "$1" == "--coverage" ]]; then
  COVERAGE=true
fi

echo "🧪 Running Reconnect tests..."
echo ""

cd "$PROJECT_DIR"

# Unit and widget tests
echo "📝 Running unit and widget tests..."
if [ "$COVERAGE" = true ]; then
  flutter test --coverage
else
  flutter test
fi

# Check test coverage
if [ "$COVERAGE" = true ]; then
  echo ""
  echo "📊 Test coverage report:"
  if command -v lcov &> /dev/null; then
    genhtml coverage/lcov.info --output-directory=coverage_report
    echo "   Coverage report generated at: coverage_report/index.html"
  else
    echo "   Coverage data available at: coverage/lcov.info"
    echo "   Install lcov to generate HTML report: brew install lcov"
  fi
fi

echo ""
echo "✅ Tests complete!"
echo ""
echo "To run integration tests on device:"
echo "  flutter test integration_test/"
