import 'dart:async';

/// Extension on Timer to create periodic timers that run immediately
extension TimerExtension on Timer {
  /// Creates a periodic timer that runs the callback immediately,
  /// then continues to run at the specified duration.
  ///
  /// Unlike [Timer.periodic], this method executes the callback
  /// immediately on the first call, then continues periodically.
  ///
  /// Example:
  /// ```dart
  /// TimerExtension.periodicAndRunNow(
  ///   Duration(seconds: 5),
  ///   (timer) {
  ///     print('This runs immediately, then every 5 seconds');
  ///   },
  /// );
  /// ```
  static Timer periodicAndRunNow(
    Duration duration,
    void Function(Timer timer) callback,
  ) {
    // Create periodic timer first
    late Timer timer;
    var isFirstRun = true;

    timer = Timer.periodic(duration, (t) {
      // Skip first periodic call since we run it immediately
      if (isFirstRun) {
        isFirstRun = false;
        return;
      }
      callback(t);
    });

    // Run callback immediately with the actual timer
    callback(timer);

    return timer;
  }
}
