#!/bin/bash

# Pre-commit hook to check test coverage
# This script ensures that test coverage doesn't decrease below threshold

set -e

# Configuration
# Read threshold from coverage config
MIN_COVERAGE=$(grep "threshold:" coverage_config.yaml | sed 's/.*threshold: *//' | sed 's/ *$//')
if [ -z "$MIN_COVERAGE" ]; then
    MIN_COVERAGE=80  # Default fallback
fi

COVERAGE_FILE="coverage/merged_lcov.info"
PREVIOUS_COVERAGE_FILE="coverage/previous_lcov.info"

echo "🔍 Running pre-commit coverage check..."

# Check if we have previous coverage data
if [ ! -f "$PREVIOUS_COVERAGE_FILE" ]; then
    echo "⚠️  No previous coverage data found. Running initial coverage check..."
    
    # Run tests with coverage
    flutter test --coverage --coverage-path=coverage/lcov.info
    flutter test test/goldens/ --coverage --coverage-path=coverage/golden_lcov.info
    
    # Merge coverage files
    lcov --add-tracefile coverage/lcov.info --add-tracefile coverage/golden_lcov.info --output-file "$COVERAGE_FILE"
    
    # Save as baseline
    cp "$COVERAGE_FILE" "$PREVIOUS_COVERAGE_FILE"
    
    echo "✅ Initial coverage baseline saved"
    exit 0
fi

# Run current tests with coverage
echo "Running tests with coverage..."
flutter test --coverage --coverage-path=coverage/lcov.info
flutter test test/goldens/ --coverage --coverage-path=coverage/golden_lcov.info

# Merge coverage files
lcov --add-tracefile coverage/lcov.info --add-tracefile coverage/golden_lcov.info --output-file "$COVERAGE_FILE"

# Get current and previous coverage percentages
CURRENT_COVERAGE=$(lcov --summary "$COVERAGE_FILE" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')
PREVIOUS_COVERAGE=$(lcov --summary "$PREVIOUS_COVERAGE_FILE" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

echo "📊 Coverage comparison:"
echo "   Previous: ${PREVIOUS_COVERAGE}%"
echo "   Current:  ${CURRENT_COVERAGE}%"

# Check minimum threshold
if (( $(echo "$CURRENT_COVERAGE < $MIN_COVERAGE" | bc -l) )); then
    echo "❌ Coverage ${CURRENT_COVERAGE}% is below minimum threshold of ${MIN_COVERAGE}%"
    echo "Please add more tests to improve coverage."
    exit 1
fi

# Check if coverage decreased significantly (more than 1%)
COVERAGE_DIFF=$(echo "$PREVIOUS_COVERAGE - $CURRENT_COVERAGE" | bc -l)
if (( $(echo "$COVERAGE_DIFF > 1.0" | bc -l) )); then
    echo "⚠️  Coverage decreased by ${COVERAGE_DIFF}%"
    echo "This might indicate missing tests for new code."
    echo "Please review and add tests if necessary."
    
    # Ask for confirmation
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Commit cancelled. Please add tests to maintain coverage."
        exit 1
    fi
fi

# Update baseline if coverage improved or stayed the same
if (( $(echo "$CURRENT_COVERAGE >= $PREVIOUS_COVERAGE" | bc -l) )); then
    cp "$COVERAGE_FILE" "$PREVIOUS_COVERAGE_FILE"
    echo "✅ Coverage baseline updated"
fi

echo "✅ Coverage check passed!"
echo "📈 Current coverage: ${CURRENT_COVERAGE}% (threshold: ${MIN_COVERAGE}%)"
