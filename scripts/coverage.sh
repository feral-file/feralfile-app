#!/bin/bash

# Comprehensive Coverage Analysis Script with Setup
# Usage: ./scripts/coverage.sh [--file=test_file.dart]
#   --file=test_file.dart: Run coverage for specific test file only
#   (no params): Run coverage for all test files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to check and install required tools
setup_tools() {
    echo "🚀 Setting up test coverage reporting for Feral File app..."
    
    # Check if required tools are installed
    echo "🔍 Checking required tools..."
    
    # Check for lcov
    if ! command -v lcov &> /dev/null; then
        echo "❌ lcov is not installed. Installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install lcov
            else
                echo "Please install Homebrew first, then run: brew install lcov"
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            sudo apt-get update
            sudo apt-get install -y lcov
        else
            echo "Please install lcov manually for your operating system"
            exit 1
        fi
    else
        echo "✅ lcov is already installed"
    fi
    
    # Check for genhtml
    if ! command -v genhtml &> /dev/null; then
        echo "❌ genhtml is not installed. Installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install lcov
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get install -y lcov
        fi
    else
        echo "✅ genhtml is already installed"
    fi
    
    # Check for bc (calculator)
    if ! command -v bc &> /dev/null; then
        echo "❌ bc is not installed. Installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install bc
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            sudo apt-get install -y bc
        fi
    else
        echo "✅ bc is already installed"
    fi
    
    echo "✅ All required tools are installed"
    
    # Create coverage_config.yaml if it doesn't exist
    if [ ! -f "coverage_config.yaml" ]; then
        echo "📝 Creating coverage_config.yaml..."
        cat > coverage_config.yaml << 'EOF'
# Coverage Configuration
# This file defines which files to include/exclude from coverage analysis

# Minimum coverage threshold (percentage)
threshold: 80

# Files to include in coverage analysis
# Only files that are imported in your test files
include:
  - lib/service/meilisearch_service.dart
  - test/unit-tests/mocks/base_mock_response.dart
  - test/unit-tests/mocks/meilisearch_mock_client.dart
  - test/unit-tests/mocks/mock_service_helper.dart
  - test/unit-tests/mocks/meilisearch_mock_data.dart
  - test/unit-tests/mocks/mock_channel_data.dart
  - test/unit-tests/mocks/mock_playlist_data.dart
  - test/unit-tests/mocks/mock_dp1_item_data.dart

# Files to exclude from coverage analysis
exclude:
  - lib/main.dart
  - lib/theme/**
  - lib/design/**
  - test/**

# Report settings
reports:
  html: true
  lcov: true
  summary: true

# Badge settings
badge:
  enabled: true
  file: coverage_badge.svg
  color_scheme: default
EOF
        echo "✅ Created coverage_config.yaml"
    else
        echo "✅ coverage_config.yaml already exists"
    fi
    
    # Create .gitignore entries for coverage files
    echo "📝 Updating .gitignore for coverage files..."
    if ! grep -q "test/coverage/" .gitignore; then
        echo "" >> .gitignore
        echo "# Coverage files" >> .gitignore
        echo "test/coverage/" >> .gitignore
        echo "coverage_badge.svg" >> .gitignore
        echo "✅ Added coverage files to .gitignore"
    else
        echo "✅ Coverage files already in .gitignore"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Setup complete!${NC}"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Run coverage analysis: ./scripts/coverage.sh"
    echo "   2. Check HTML report: test/coverage/html/index.html"
    echo "   3. Add more tests to improve coverage"
    echo ""
    echo "🔗 Useful commands:"
    echo "   - Generate coverage: ./scripts/coverage.sh"
    echo "   - Update badge: ./scripts/update-coverage-badge.sh"
    echo "   - Check threshold: ./scripts/pre-commit-coverage-check.sh"
}

# Function to run coverage analysis
run_coverage() {
    local test_file="$1"
    
    # Allow tests to fail but still continue to generate reports
    set +e
    if [ -n "$test_file" ]; then
        echo "🔍 Running tests with coverage for: $test_file"
        flutter test --coverage --coverage-path=test/coverage/lcov.info "test/$test_file"
        TEST_EXIT_CODE=$?
    else
        echo "🔍 Running tests with coverage for all test files..."
        flutter test --coverage --coverage-path=test/coverage/lcov.info
        TEST_EXIT_CODE=$?
    fi
    set -e

    if [ $TEST_EXIT_CODE -ne 0 ]; then
        echo -e "${YELLOW}⚠️ Tests failed, attempting to generate coverage report from partial data...${NC}"
    else
        echo -e "${GREEN}✅ Tests passed. Generating coverage report...${NC}"
    fi

    # Get overall coverage
    if [ -f "test/coverage/lcov.info" ]; then
        OVERALL_COVERAGE=$(lcov --summary test/coverage/lcov.info | grep -o '[0-9.]*%' | head -1)
    else
        echo -e "${RED}❌ coverage file not found at test/coverage/lcov.info${NC}"
        OVERALL_COVERAGE="0%"
    fi
    echo ""
    echo "📊 Coverage Analysis Report"
    echo "=========================="
    echo -e "${BLUE}📈 Overall Coverage: ${OVERALL_COVERAGE}${NC}"
    echo ""

    # Generate HTML report
    echo "📊 Generating detailed HTML report..."
    if [ -f "test/coverage/lcov.info" ]; then
        genhtml test/coverage/lcov.info -o test/coverage/html --ignore-errors source --quiet
    else
        echo -e "${RED}❌ Skipping HTML generation due to missing lcov.info${NC}"
    fi

    # Extract files with coverage using a simple approach
    echo -e "${CYAN}📋 Files with Coverage (hit > 0):${NC}"
    echo "================================="

    # Use genhtml output to find files with coverage
    if [ -f "test/coverage/html/index.html" ]; then
        # Find all HTML files in the coverage directory (excluding index.html)
        find test/coverage/html -name "*.html" -not -name "index.html" | while read html_file; do
            # Extract coverage data from each HTML file
            lines=$(grep -o 'lines: [0-9]*' "$html_file" | grep -o '[0-9]*' | head -1)
            hit=$(grep -o 'hit: [0-9]*' "$html_file" | grep -o '[0-9]*' | head -1)
            
            if [ -n "$hit" ] && [ -n "$lines" ] && [ "$hit" -gt 0 ]; then
                # Calculate coverage percentage
                coverage_percent=$(echo "scale=1; $hit * 100 / $lines" | bc)
                
                # Get file path from HTML filename
                file_path=$(basename "$html_file" .html)
                
                # Color code based on coverage
                if (( $(echo "$coverage_percent >= 90" | bc -l) )); then
                    color=$GREEN
                    status="✅"
                elif (( $(echo "$coverage_percent >= 80" | bc -l) )); then
                    color=$YELLOW
                    status="⚠️"
                else
                    color=$RED
                    status="❌"
                fi
                
                echo -e "${color}${status} ${coverage_percent}%${NC} (${hit}/${lines}) ${file_path}"
            fi
        done
    else
        echo "❌ HTML report not generated"
    fi

    echo ""
    echo -e "${CYAN}📁 Test Files Coverage:${NC}"
    echo "---------------------------"

    # Find all test files and analyze their coverage
    find test/ -name "*_test.dart" -type f | while read test_file; do
        echo -e "${BLUE}🧪 Test: ${test_file}${NC}"
        
        # Extract the corresponding source file
        if [[ "$test_file" == *"unit-tests"* ]]; then
            source_file=$(echo "$test_file" | sed 's|test/unit-tests/||' | sed 's|_test\.dart|.dart|' | sed 's|^|lib/|')
        elif [[ "$test_file" == *"goldens"* ]]; then
            source_file=$(echo "$test_file" | sed 's|test/goldens/||' | sed 's|_golden_test\.dart|.dart|' | sed 's|^|lib/view/|')
        else
            source_file=$(echo "$test_file" | sed 's|test/||' | sed 's|_test\.dart|.dart|' | sed 's|^|lib/|')
        fi
        
        if [ -f "$source_file" ]; then
            # Get coverage for this specific file from HTML report
            html_file="test/coverage/html/$(basename "$source_file" .dart).html"
            if [ -f "$html_file" ]; then
                lines=$(grep -o 'lines: [0-9]*' "$html_file" | grep -o '[0-9]*' | head -1)
                hit=$(grep -o 'hit: [0-9]*' "$html_file" | grep -o '[0-9]*' | head -1)
                
                if [ -n "$hit" ] && [ -n "$lines" ] && [ "$hit" -gt 0 ]; then
                    coverage_percent=$(echo "scale=1; $hit * 100 / $lines" | bc)
                    
                    if (( $(echo "$coverage_percent >= 90" | bc -l) )); then
                        color=$GREEN
                        status="✅"
                    elif (( $(echo "$coverage_percent >= 80" | bc -l) )); then
                        color=$YELLOW
                        status="⚠️"
                    else
                        color=$RED
                        status="❌"
                    fi
                    
                    echo -e "   ${color}${status} ${coverage_percent}%${NC} (${hit}/${lines}) - ${source_file}"
                fi
            fi
        fi
        echo ""
    done

    echo -e "${GREEN}✅ Coverage analysis complete!${NC}"
    echo ""
    echo "📁 Reports available at:"
    echo "   - HTML Report: test/coverage/html/index.html"
    echo "   - LCOV Data: test/coverage/lcov.info"
    echo ""
    echo "💡 Tips:"
    echo "   - Open HTML report for detailed line-by-line coverage"
    echo "   - Focus on files with low coverage (< 80%)"
    echo "   - Add more test cases for uncovered lines"
}

# Parse command line arguments
TEST_FILE=""
for arg in "$@"; do
    case $arg in
        --file=*)
            TEST_FILE="${arg#*=}"
            ;;
        --help|-h)
            echo "Usage: $0 [--file=test_file.dart]"
            echo "  --file=test_file.dart: Run coverage for specific test file only"
            echo "  (no params): Run coverage for all test files"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run all tests"
            echo "  $0 --file=unit-tests/calculator_test.dart  # Run specific test"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Main script logic - always run setup first, then coverage analysis
if [ -n "$TEST_FILE" ]; then
    echo "🚀 Starting coverage analysis for: $TEST_FILE"
else
    echo "🚀 Starting coverage analysis for all test files"
fi
echo ""

# Always run setup first
setup_tools

echo ""
echo "🔍 Running coverage analysis..."
echo ""

# Then run coverage analysis
run_coverage "$TEST_FILE"