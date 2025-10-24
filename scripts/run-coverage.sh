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
rm -rf test/coverage/
mkdir -p test/coverage

# Run unit tests with coverage
echo "📊 Running unit tests with coverage..."
flutter test --coverage --coverage-path=test/coverage/lcov.info

# Generate HTML coverage report
echo "📈 Generating HTML coverage report..."
genhtml test/coverage/lcov.info -o test/coverage/html --ignore-errors source

# Generate coverage summary
echo "📋 Generating coverage summary..."
lcov --summary test/coverage/lcov.info > test/coverage/summary.txt

# Extract coverage percentage
COVERAGE_PERCENT=$(lcov --summary test/coverage/lcov.info | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

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
echo "   📊 HTML Report: test/coverage/html/index.html"
echo "   📄 LCOV Data: test/coverage/lcov.info"
echo "   📋 Summary: test/coverage/summary.txt"

# Open HTML report if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    read -p "🌐 Open HTML coverage report in browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open test/coverage/html/index.html
    fi
fi

echo ""
echo -e "${GREEN}🎉 Coverage analysis complete!${NC}"
