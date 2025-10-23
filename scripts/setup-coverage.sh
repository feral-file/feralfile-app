#!/bin/bash

# Setup script for test coverage reporting
# This script sets up the necessary tools and configurations for coverage reporting

set -e

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

# Create coverage directory
echo "📁 Creating coverage directory..."
mkdir -p coverage

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/update-coverage-badge.sh
chmod +x scripts/pre-commit-coverage-check.sh

# Create .gitignore entries for coverage files
echo "📝 Updating .gitignore for coverage files..."
if ! grep -q "coverage/" .gitignore; then
    echo "" >> .gitignore
    echo "# Coverage files" >> .gitignore
    echo "coverage/" >> .gitignore
    echo "lcov.info" >> .gitignore
    echo "*.lcov" >> .gitignore
fi

# Create initial coverage baseline
echo "📊 Creating initial coverage baseline..."
if [ ! -f "coverage/previous_lcov.info" ]; then
    echo "Running initial coverage check..."
    flutter test --coverage --coverage-path=coverage/lcov.info
    flutter test test/goldens/ --coverage --coverage-path=coverage/golden_lcov.info
    
    # Merge coverage files
    lcov --add-tracefile coverage/lcov.info --add-tracefile coverage/golden_lcov.info --output-file coverage/merged_lcov.info
    
    # Save as baseline
    cp coverage/merged_lcov.info coverage/previous_lcov.info
    
    echo "✅ Initial coverage baseline created"
else
    echo "✅ Coverage baseline already exists"
fi

# Generate initial coverage report
echo "📈 Generating initial coverage report..."
./scripts/update-coverage-badge.sh

# Setup pre-commit hook (optional)
echo "🔗 Setting up pre-commit hook..."
if [ -d ".git/hooks" ]; then
    cp scripts/pre-commit-coverage-check.sh .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "✅ Pre-commit hook installed"
else
    echo "⚠️  Not a git repository, skipping pre-commit hook setup"
fi

# Create coverage configuration file
echo "⚙️  Creating coverage configuration..."
cat > coverage_config.yaml << EOF
# Coverage configuration for Feral File app
coverage:
  # Minimum coverage threshold (Orbit 1 quality guardrails)
  threshold: 80
  
  # Coverage paths to include
  include:
    - "lib/**/*.dart"
    - "test/**/*.dart"
  
  # Coverage paths to exclude
  exclude:
    - "lib/**/*.g.dart"
    - "lib/**/*.freezed.dart"
    - "lib/main.dart"
    - "lib/**/*_test.dart"
    - "test/**/*_test.dart"
  
  # Coverage report formats
  formats:
    - html
    - lcov
    - json
  
  # Coverage report output directory
  output_dir: "coverage"
  
  # Coverage badge configuration
  badge:
    enabled: true
    color_thresholds:
      excellent: 90
      good: 80
      poor: 70
EOF

echo "✅ Coverage configuration created: coverage_config.yaml"

# Create coverage README
echo "📚 Creating coverage documentation..."
cat > COVERAGE.md << EOF
# Test Coverage

This document describes the test coverage setup for the Feral File mobile app.

## Coverage Requirements

- **Minimum Threshold**: 80% (Orbit 1 quality guardrails)
- **Target**: 90%+ for excellent coverage
- **Measurement**: Line coverage for unit tests and golden tests

## Running Coverage Reports

### Local Development

\`\`\`bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Update coverage badge
./scripts/update-coverage-badge.sh
\`\`\`

### CI/CD

Coverage reports are automatically generated in CI:
- **Workflow**: \`.github/workflows/test-coverage.yaml\`
- **Triggers**: Push to main/develop, Pull requests
- **Threshold**: Enforced at 80% minimum
- **Reports**: Uploaded as artifacts and sent to Codecov

## Coverage Reports

- **HTML Report**: \`coverage/html/index.html\`
- **LCOV Data**: \`coverage/merged_lcov.info\`
- **Summary**: \`coverage/summary.txt\`

## Coverage Badge

The coverage badge is automatically updated and displayed in the README:
![Coverage](https://img.shields.io/badge/coverage-XX%25-COLOR)

## Pre-commit Hook

A pre-commit hook is installed to check coverage before commits:
- Prevents coverage from dropping below threshold
- Warns if coverage decreases significantly
- Updates baseline when coverage improves

## Configuration

Coverage settings can be modified in \`coverage_config.yaml\`.

## Troubleshooting

### Common Issues

1. **Low Coverage**: Add more unit tests for uncovered code
2. **Missing Dependencies**: Run \`./scripts/setup-coverage.sh\` to install required tools
3. **CI Failures**: Check coverage threshold and add tests as needed

### Tools Required

- \`lcov\`: Coverage data manipulation
- \`genhtml\`: HTML report generation
- \`bc\`: Calculator for threshold comparisons
EOF

echo "✅ Coverage documentation created: COVERAGE.md"

echo ""
echo "🎉 Test coverage reporting setup complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Review coverage_config.yaml for your specific needs"
echo "   2. Run './scripts/update-coverage-badge.sh' to generate initial badge"
echo "   3. Add more tests to improve coverage"
echo "   4. Check COVERAGE.md for detailed documentation"
echo ""
echo "🔗 Useful commands:"
echo "   - Generate coverage: flutter test --coverage"
echo "   - Update badge: ./scripts/update-coverage-badge.sh"
echo "   - Check threshold: ./scripts/pre-commit-coverage-check.sh"
