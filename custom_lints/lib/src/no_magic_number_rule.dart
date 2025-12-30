import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that detects magic numbers in UI code.
///
/// This rule enforces the use of AppTypography and LayoutConstants
/// instead of hard-coded numeric values for:
/// - Font sizes
/// - Padding, margins, spacing
/// - Widget dimensions (width, height, size)
/// - Icon sizes
/// - Border radius
///
/// Allowed values:
/// - 0, 1 (common for conditions, multipliers)
/// - math.pi and other mathematical constants
/// - Opacity values (0.0-1.0)
/// - Angle calculations
class NoMagicNumberRule extends DartLintRule {
  const NoMagicNumberRule() : super(code: _code);

  static const _code = LintCode(
    name: 'no_magic_number',
    problemMessage: 'Avoid magic numbers in UI code. '
        'Use LayoutConstants for spacing/dimensions or AppTypography for text styles.',
    correctionMessage:
        'Replace hard-coded numbers with constants from LayoutConstants or AppTypography. '
        'Example: Instead of EdgeInsets.all(20), use EdgeInsets.all(LayoutConstants.space5)',
  );

  // Allowed numeric values that aren't considered "magic"
  static const _allowedValues = {
    0,
    1,
    -1,
  };

  // Flutter widgets/properties that commonly have magic numbers
  static const _uiProperties = {
    // EdgeInsets
    'all',
    'only',
    'symmetric',
    'fromLTRB',
    'padding',
    'margin',
    // SizedBox
    'width',
    'height',
    'size',
    // TextStyle
    'fontSize',
    'letterSpacing',
    'wordSpacing',
    // BorderRadius
    'circular',
    'radius',
    // Icon/Image sizes
    'iconSize',
    // Positioning
    'top',
    'bottom',
    'left',
    'right',
    // Constraints
    'minWidth',
    'maxWidth',
    'minHeight',
    'maxHeight',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      _checkInstanceCreation(node, reporter);
    });

    context.registry.addNamedExpression((node) {
      _checkNamedExpression(node, reporter);
    });

    context.registry.addAssignmentExpression((node) {
      _checkAssignment(node, reporter);
    });
  }

  void _checkInstanceCreation(
    InstanceCreationExpression node,
    ErrorReporter reporter,
  ) {
    final typeName = node.constructorName.type.toString();

    // Check for UI-related constructors
    if (_isUIConstructor(typeName)) {
      _checkArguments(node.argumentList.arguments, reporter);
    }
  }

  void _checkNamedExpression(NamedExpression node, ErrorReporter reporter) {
    final paramName = node.name.label.name;

    // Check if this is a UI property
    if (_uiProperties.contains(paramName)) {
      final expression = node.expression;
      _checkExpression(expression, reporter);
    }
  }

  void _checkAssignment(AssignmentExpression node, ErrorReporter reporter) {
    // Check property assignments (e.g., widget.width = 100)
    final target = node.leftHandSide;
    if (target is PropertyAccess) {
      final propertyName = target.propertyName.name;
      if (_uiProperties.contains(propertyName)) {
        _checkExpression(node.rightHandSide, reporter);
      }
    }
  }

  void _checkArguments(
    NodeList<Expression> arguments,
    ErrorReporter reporter,
  ) {
    for (final arg in arguments) {
      _checkExpression(arg, reporter);
    }
  }

  void _checkExpression(Expression expression, ErrorReporter reporter) {
    // Handle named expressions
    if (expression is NamedExpression) {
      _checkExpression(expression.expression, reporter);
      return;
    }

    // Check for numeric literals
    if (expression is IntegerLiteral || expression is DoubleLiteral) {
      final value = _getNumericValue(expression);
      if (value != null && !_isAllowedValue(value, expression)) {
        reporter.reportErrorForNode(code, expression);
      }
    }

    // Check for negative numbers (e.g., -6)
    if (expression is PrefixExpression &&
        expression.operator.lexeme == '-' &&
        (expression.operand is IntegerLiteral ||
            expression.operand is DoubleLiteral)) {
      final value = _getNumericValue(expression.operand);
      if (value != null && !_isAllowedValue(-value, expression)) {
        reporter.reportErrorForNode(code, expression);
      }
    }

    // Recursively check method invocations
    if (expression is MethodInvocation) {
      _checkArguments(expression.argumentList.arguments, reporter);
    }

    // Recursively check instance creations
    if (expression is InstanceCreationExpression) {
      _checkArguments(expression.argumentList.arguments, reporter);
    }
  }

  double? _getNumericValue(Expression expression) {
    if (expression is IntegerLiteral) {
      return expression.value?.toDouble();
    }
    if (expression is DoubleLiteral) {
      return expression.value;
    }
    return null;
  }

  bool _isAllowedValue(double value, Expression expression) {
    // Allow whitelisted values
    if (_allowedValues.contains(value.toInt()) && value == value.toInt()) {
      return true;
    }

    // Allow opacity values (0.0 to 1.0) in specific contexts
    if (value >= 0.0 && value <= 1.0 && _isOpacityContext(expression)) {
      return true;
    }

    // Allow math.pi and fractions of pi
    if (_isMathContext(expression)) {
      return true;
    }

    return false;
  }

  bool _isOpacityContext(Expression expression) {
    final parent = expression.parent;
    if (parent is NamedExpression) {
      final paramName = parent.name.label.name;
      return paramName == 'opacity' || paramName == 'alpha';
    }
    return false;
  }

  bool _isMathContext(Expression expression) {
    // Check if we're in a mathematical expression (e.g., math.pi / 4)
    var parent = expression.parent;
    while (parent != null) {
      if (parent is BinaryExpression) {
        // Check if one side is a math constant
        final leftString = parent.leftOperand.toString();
        final rightString = parent.rightOperand.toString();
        if (leftString.contains('math.pi') ||
            rightString.contains('math.pi') ||
            leftString.contains('pi') ||
            rightString.contains('pi')) {
          return true;
        }
      }
      parent = parent.parent;
    }
    return false;
  }

  bool _isUIConstructor(String typeName) {
    // List of Flutter UI widgets/classes that commonly have magic numbers
    const uiTypes = {
      'EdgeInsets',
      'EdgeInsetsDirectional',
      'SizedBox',
      'Container',
      'Padding',
      'TextStyle',
      'BorderRadius',
      'Positioned',
      'Radius',
      'Size',
      'Icon',
      'SvgPicture',
      'Image',
      'Transform',
      'BoxConstraints',
    };

    return uiTypes.any((type) => typeName.startsWith(type));
  }
}

