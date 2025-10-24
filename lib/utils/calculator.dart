// Simple calculator utility for testing coverage
class Calculator {
  int add(int a, int b) => a + b;
  int subtract(int a, int b) => a - b;
  int multiply(int a, int b) => a * b;
  double divide(int a, int b) {
    if (b == 0) throw ArgumentError('Cannot divide by zero');
    return a / b;
  }

  bool isEven(int number) => number % 2 == 0;
  bool isOdd(int number) => number % 2 != 0;

  int factorial(int n) {
    if (n < 0)
      throw ArgumentError('Factorial is not defined for negative numbers');
    if (n <= 1) return 1;
    return n * factorial(n - 1);
  }
}
