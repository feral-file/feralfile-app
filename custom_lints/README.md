# Custom Lint Rules for FeralFile App

This package contains custom lint rules to enforce design system usage and code quality standards in the FeralFile Flutter app.

## Rules

### `no_magic_number`

**Severity**: Warning (INFO)

**Purpose**: Detects hard-coded numeric values in UI code and enforces the use of `LayoutConstants` for spacing/dimensions and `AppTypography` for text styles.

#### What it detects:

- Hard-coded padding, margins, and spacing values
- Hard-coded widget dimensions (width, height, size)
- Hard-coded font sizes, letter spacing
- Hard-coded icon sizes
- Hard-coded positioning values (top, bottom, left, right)
- Hard-coded border radius values

#### Allowed values (not considered magic):

- `0`, `1`, `-1` (common for conditions, multipliers, and resets)
- Opacity values between `0.0` and `1.0` (when used in opacity contexts)
- Mathematical expressions with `math.pi` (e.g., `math.pi / 4`)

#### Examples:

**❌ Bad (will trigger warning):**

```dart
Container(
  padding: EdgeInsets.all(20),  // Magic number!
  width: 243,                    // Magic number!
  child: Text(
    'Title',
    style: TextStyle(fontSize: 16), // Magic number!
  ),
)

Positioned(
  top: 10,    // Magic number!
  right: 10,  // Magic number!
  child: Icon(Icons.close, size: 24), // Magic number!
)
```

**✅ Good:**

```dart
Container(
  padding: EdgeInsets.all(LayoutConstants.space5),
  width: LayoutConstants.tooltipWidth,
  child: Text(
    'Title',
    style: AppTypography.h4(context),
  ),
)

Positioned(
  top: LayoutConstants.space2,
  right: LayoutConstants.space2,
  child: Icon(
    Icons.close,
    size: LayoutConstants.iconSizeSmall,
  ),
)
```

## Usage

### Local Development

**Important**: `flutter analyze` does NOT automatically run custom lint rules. You must run `dart run custom_lint` separately.

```bash
# Check for lint issues (including magic numbers)
dart run custom_lint

# Check a specific file
dart run custom_lint lib/view/cast_button.dart

# Check and treat warnings as errors (CI mode)
dart run custom_lint --fatal-warnings

# Watch mode (real-time feedback)
dart run custom_lint --watch

# Standard flutter analyze (does NOT include custom lint)
flutter analyze
```

### IDE Integration

The custom lint rules automatically integrate with your IDE when you have the `custom_lint` package installed. You'll see warnings in your editor as you code.

**VS Code/Cursor**: Warnings appear as squiggly lines with hover tooltips.

**Android Studio/IntelliJ**: Warnings appear in the inspection panel.

### CI Integration

**Note**: Custom lint rules are automatically integrated into the existing lint workflow at `.github/workflows/lint.yaml`. The workflow runs both `flutter analyze` and `dart run custom_lint` separately, with reviewdog reporting issues on PRs.

#### How it works in CI:

1. **`flutter analyze`**: Runs standard Flutter/Dart linter rules
2. **`dart run custom_lint`**: Runs custom rules (like `no_magic_number`) 
3. **reviewdog**: Posts both types of issues as PR comments

#### Manual GitHub Actions Example

If you want to add it to a different workflow:

```yaml
name: Lint

on:
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run Flutter analyzer
        run: flutter analyze
      
      - name: Run custom lint (fail on warnings)
        run: dart run custom_lint --fatal-warnings
```

#### GitLab CI Example

```yaml
lint:
  stage: test
  image: cirrusci/flutter:stable
  script:
    - flutter pub get
    - flutter analyze
    - dart run custom_lint --fatal-warnings
  only:
    - merge_requests
    - main
    - develop
```

#### Pre-commit Hook Example

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running custom lint checks..."

# Run custom lint
dart run custom_lint --fatal-warnings

if [ $? -ne 0 ]; then
  echo "❌ Custom lint checks failed. Please fix magic numbers before committing."
  echo "Use LayoutConstants for spacing/dimensions and AppTypography for text styles."
  exit 1
fi

echo "✅ Custom lint checks passed"
exit 0
```

Make it executable:

```bash
chmod +x .git/hooks/pre-commit
```

## Configuration

The rule is enabled in the main project's `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    - no_magic_number
```

To disable the rule for a specific file or line, use:

```dart
// ignore_for_file: no_magic_number

// or for a specific line:
Container(
  width: 100, // ignore: no_magic_number
)
```

**Note**: Use `ignore` sparingly and only when absolutely necessary (e.g., when interfacing with third-party APIs that require specific numeric values).

## Development

To modify or add new custom lint rules:

1. Edit or create rule files in `lib/src/`
2. Register the rule in `lib/custom_lints.dart`
3. Test locally with `dart run custom_lint`
4. Update this README with rule documentation

### Testing

Test the rule on a specific file:

```bash
dart run custom_lint lib/view/cast_button.dart
```

## Troubleshooting

### Rule not triggering

1. Clean custom_lint cache:
   ```bash
   dart run custom_lint --fatal-warnings
   rm -rf .dart_tool/custom_lint
   ```

2. Restart your IDE's Dart Analysis Server

3. Verify the rule is enabled in `analysis_options.yaml`

### False positives

If the rule incorrectly flags valid code:

1. Check if the value should be added to the allowlist in `no_magic_number_rule.dart`
2. Use `// ignore: no_magic_number` for legitimate exceptions
3. Consider adding the value to `LayoutConstants` or using an existing constant

## References

- [custom_lint documentation](https://pub.dev/packages/custom_lint)
- [LayoutConstants](../lib/design/build/layout_constants.dart)
- [AppTypography](../lib/design/build/typography.dart)
- [FeralFile Cursor Rules](../.cursor_rules)

