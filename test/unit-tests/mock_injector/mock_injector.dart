import 'package:autonomy_flutter/common/injector.dart';
import 'package:get_it/get_it.dart';

final mockInjector = GetIt.instance;

class MockInjector {
  // singleton instance
  MockInjector._();
  static final MockInjector _instance = MockInjector._();

  static MockInjector get instance => _instance;

  static void setup() {}
}
