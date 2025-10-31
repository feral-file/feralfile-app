import 'package:flutter_test/flutter_test.dart';
import 'package:autonomy_flutter/utils/calculator.dart';

void main() {
  group('Calculator Tests', () {
    late Calculator calculator;

    setUp(() {
      calculator = Calculator();
    });

    test('should add two numbers correctly', () {
      expect(calculator.add(2, 3), equals(5));
      expect(calculator.add(-1, 1), equals(0));
      expect(calculator.add(0, 0), equals(0));
    });

    test('should subtract two numbers correctly', () {
      expect(calculator.subtract(5, 3), equals(2));
      expect(calculator.subtract(1, 1), equals(0));
      expect(calculator.subtract(0, 5), equals(-5));
    });

    test('should multiply two numbers correctly', () {
      expect(calculator.multiply(2, 3), equals(6));
      expect(calculator.multiply(-2, 3), equals(-6));
      expect(calculator.multiply(0, 5), equals(0));
    });

    test('should divide two numbers correctly', () {
      expect(calculator.divide(6, 2), equals(3.0));
      expect(calculator.divide(5, 2), equals(2.5));
    });

    test('should throw error when dividing by zero', () {
      expect(() => calculator.divide(5, 0), throwsArgumentError);
    });

    test('should check if number is even', () {
      expect(calculator.isEven(2), isTrue);
      expect(calculator.isEven(3), isFalse);
      expect(calculator.isEven(0), isTrue);
    });

    test('should check if number is odd', () {
      expect(calculator.isOdd(3), isTrue);
      expect(calculator.isOdd(2), isFalse);
      expect(calculator.isOdd(0), isFalse);
    });

    test('should calculate factorial', () {
      expect(calculator.factorial(0), equals(1));
      expect(calculator.factorial(1), equals(1));
      expect(calculator.factorial(5), equals(120));
      expect(calculator.factorial(3), equals(6));
    });

    test('should throw error for negative factorial', () {
      expect(() => calculator.factorial(-1), throwsArgumentError);
    });
  });
}
