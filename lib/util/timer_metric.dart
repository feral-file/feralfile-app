import 'package:autonomy_flutter/util/log.dart';

Future<T> timerMetric<T>(String name, Future<T> Function() func) async {
  final start = DateTime.now();
  final res = await func();
  final end = DateTime.now();
  final duration = end.difference(start);
  log.info('Execution function ${name} took $duration');
  return res;
}
