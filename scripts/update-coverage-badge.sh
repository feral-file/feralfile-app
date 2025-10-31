#!/bin/bash

# Script to generate coverage badge and update README
# Usage: ./scripts/update-coverage-badge.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Generating coverage badge..."

# Run tests with coverage
echo "Running tests with coverage..."
flutter test --coverage --coverage-path=test/coverage/lcov.info

# Generate HTML report
echo "Generating HTML coverage report..."
genhtml test/coverage/lcov.info -o test/coverage/html --ignore-errors source

# Read threshold from coverage config
MIN_COVERAGE=$(grep "threshold:" coverage_config.yaml | sed 's/.*threshold: *//' | sed 's/ *$//')
if [ -z "$MIN_COVERAGE" ]; then
    MIN_COVERAGE=80  # Default fallback
fi

# Extract coverage percentage
COVERAGE_PERCENT=$(lcov --summary test/coverage/lcov.info | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

echo "📊 Current coverage: ${COVERAGE_PERCENT}% (threshold: ${MIN_COVERAGE}%)"

# Determine badge color
COVERAGE_COLOR="red"
if (( $(echo "$COVERAGE_PERCENT >= 90" | bc -l) )); then
    COVERAGE_COLOR="brightgreen"
    echo -e "${GREEN}✅ Excellent coverage!${NC}"
elif (( $(echo "$COVERAGE_PERCENT >= $MIN_COVERAGE" | bc -l) )); then
    COVERAGE_COLOR="yellow"
    echo -e "${YELLOW}⚠️  Good coverage, but could be better${NC}"
else
    echo -e "${RED}❌ Coverage below threshold (${MIN_COVERAGE}%)${NC}"
fi

# Generate badge URL
BADGE_URL="https://img.shields.io/badge/coverage-${COVERAGE_PERCENT}%25-${COVERAGE_COLOR}"

echo "🏷️  Coverage badge URL: $BADGE_URL"

# Update README if it exists
if [ -f "README.md" ]; then
    echo "📝 Updating README.md with coverage badge..."
    
    # Create backup
    cp README.md README.md.backup
    
    # Update or add coverage badge
    if grep -q "coverage-" README.md; then
        # Update existing badge
        sed -i.bak "s|https://img\.shields\.io/badge/coverage-[0-9.]*%25-[a-z]*|$BADGE_URL|g" README.md
    else
        # Add new badge at the top
        sed -i.bak "1i\\
![Coverage]($BADGE_URL)\\
" README.md
    fi
    
    echo "✅ README.md updated with coverage badge"
else
    echo "⚠️  README.md not found, skipping update"
fi

# Generate coverage summary
echo "📋 Generating coverage summary..."
lcov --summary test/coverage/lcov.info > test/coverage/summary.txt
cat test/coverage/summary.txt

echo "🎉 Coverage badge generation complete!"
echo "📁 Coverage reports saved to:"
echo "   - HTML report: test/coverage/html/index.html"
echo "   - LCOV data: test/coverage/lcov.info"
echo "   - Summary: test/coverage/summary.txt"
