#!/bin/bash

# Local coverage runner script
# This script runs tests with coverage and generates reports locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Running Flutter tests with coverage...${NC}"

# Clean previous coverage data
echo "🧹 Cleaning previous coverage data..."
rm -rf coverage/
mkdir -p coverage

# Run unit tests with coverage
echo "📊 Running unit tests with coverage..."
flutter test --coverage --coverage-path=coverage/lcov.info

# Run golden tests with coverage
echo "🖼️  Running golden tests with coverage..."
flutter test test/goldens/ --coverage --coverage-path=coverage/golden_lcov.info

# Merge coverage files
echo "🔗 Merging coverage files..."
lcov --add-tracefile coverage/lcov.info --add-tracefile coverage/golden_lcov.info --output-file coverage/merged_lcov.info

# Generate HTML coverage report
echo "📈 Generating HTML coverage report..."
genhtml coverage/merged_lcov.info -o coverage/html --ignore-errors source

# Generate coverage summary
echo "📋 Generating coverage summary..."
lcov --summary coverage/merged_lcov.info > coverage/summary.txt

# Extract coverage percentage
COVERAGE_PERCENT=$(lcov --summary coverage/merged_lcov.info | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

echo ""
echo -e "${BLUE}📊 Coverage Results:${NC}"
echo "=================="

# Display coverage summary
cat coverage/summary.txt

echo ""
echo -e "${BLUE}📈 Coverage Percentage: ${COVERAGE_PERCENT}%${NC}"

# Check against threshold
MIN_COVERAGE=80
if (( $(echo "$COVERAGE_PERCENT >= $MIN_COVERAGE" | bc -l) )); then
    echo -e "${GREEN}✅ Coverage meets minimum threshold of ${MIN_COVERAGE}%${NC}"
else
    echo -e "${RED}❌ Coverage ${COVERAGE_PERCENT}% is below minimum threshold of ${MIN_COVERAGE}%${NC}"
    echo -e "${YELLOW}💡 Consider adding more tests to improve coverage${NC}"
fi

echo ""
echo -e "${BLUE}📁 Coverage Reports Generated:${NC}"
echo "   📊 HTML Report: coverage/html/index.html"
echo "   📄 LCOV Data: coverage/merged_lcov.info"
echo "   📋 Summary: coverage/summary.txt"

# Open HTML report if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    read -p "🌐 Open HTML coverage report in browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open coverage/html/index.html
    fi
fi

echo ""
echo -e "${GREEN}🎉 Coverage analysis complete!${NC}"
