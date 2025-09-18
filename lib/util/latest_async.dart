//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

/// LatestAsync ensures that only the latest started async task
/// is allowed to deliver its result. Older, slower responses are ignored.
///
/// Usage example:
///
/// final latest = LatestAsync<SearchResult>();
/// latest.run(
///   () => service.search(query),
///   onData: (result) {
///     // Only called for the most recent run()
///   },
///   onError: (e, st) {
///     // Optional error handling for the most recent run()
///   },
/// );
class LatestAsync<T> {
  int _counter = 0;
  Timer? _debounceTimer;
  Completer<void>? _debounceCompleter;
  Timer? _maxWaitTimer;
  final List<Completer<void>> _waitingCompleters = [];

  /// Run an async [task]. If a new run starts before this [task] completes,
  /// the result of this [task] will be ignored.
  Future<void> run(
    Future<T> Function() task, {
    required void Function(T value) onData,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration debounce = const Duration(milliseconds: 150),
    Duration? maxWait = const Duration(seconds: 1),
  }) async {
    // Debounce: delay the execution; only the last scheduled will run
    if (debounce.inMilliseconds > 0) {
      // Cancel pending debounce and complete its future to avoid dangling awaits
      if (_debounceTimer?.isActive ?? false) {
        _debounceTimer!.cancel();
        _debounceCompleter?.complete();
      }

      final int requestId = ++_counter;
      final completer = Completer<void>();
      _debounceCompleter = completer;

      void execute() async {
        // Cancel both timers to prevent double execution
        _debounceTimer?.cancel();
        _maxWaitTimer?.cancel();
        _maxWaitTimer = null;

        try {
          final T value = await task();
          if (requestId == _counter) {
            onData(value);
          }
        } catch (error, stackTrace) {
          if (requestId == _counter) {
            if (onError != null) onError(error, stackTrace);
          }
        } finally {
          if (!completer.isCompleted) completer.complete();
          // Complete all waiting completers
          _completeWaitingCompleters();
        }
      }

      _debounceTimer = Timer(debounce, execute);

      // Ensure task runs at most after maxWait even if new calls keep arriving
      if (maxWait != null && maxWait.inMilliseconds > 0) {
        _maxWaitTimer ??= Timer(maxWait, () {
          // Cancel debounce timer to prevent double execution
          if (_debounceTimer?.isActive ?? false) {
            _debounceTimer!.cancel();
          }
          execute();
        });
      }

      return completer.future;
    }

    // Immediate execution (no debounce)
    final int requestId = ++_counter;
    try {
      final T value = await task();
      if (requestId == _counter) {
        onData(value);
      }
    } catch (error, stackTrace) {
      if (requestId == _counter) {
        if (onError != null) onError(error, stackTrace);
      }
    } finally {
      // Complete all waiting completers
      _completeWaitingCompleters();
    }
  }

  /// Clears all in-flight runs by advancing the internal counter.
  /// Subsequent late results from earlier runs will be ignored.
  void cancelInFlight() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      _debounceCompleter?.complete();
    }
    if (_maxWaitTimer?.isActive ?? false) {
      _maxWaitTimer!.cancel();
    }
    _counter++;
    // Complete all waiting completers
    _completeWaitingCompleters();
  }

  /// Returns true if the latest task is currently running or waiting to run.
  /// This includes tasks that are:
  /// - Waiting for debounce timer
  /// - Currently executing
  /// - Waiting for maxWait timer
  bool get isRunning {
    return (_debounceTimer?.isActive ?? false) ||
        (_maxWaitTimer?.isActive ?? false) ||
        (_debounceCompleter != null && !_debounceCompleter!.isCompleted);
  }

  /// Returns true if the latest task has finished (either successfully or with error).
  /// This is the opposite of [isRunning].
  bool get isFinished {
    return !isRunning;
  }

  /// Returns true if there is currently a task waiting for debounce timer.
  bool get isWaitingForDebounce {
    return _debounceTimer?.isActive ?? false;
  }

  /// Returns true if there is currently a task waiting for maxWait timer.
  bool get isWaitingForMaxWait {
    return _maxWaitTimer?.isActive ?? false;
  }

  /// Returns true if there is currently a task executing (not waiting for timers).
  bool get isExecuting {
    return _debounceCompleter != null &&
        !_debounceCompleter!.isCompleted &&
        !isWaitingForDebounce;
  }

  /// Returns the current request counter value.
  /// This can be used to track which task is the latest.
  int get currentRequestId => _counter;

  /// Returns a Completer that will complete when the current latest task finishes.
  /// If no task is currently running, the completer will complete immediately.
  ///
  /// Usage example:
  /// ```dart
  /// final latest = LatestAsync<SearchResult>();
  /// latest.run(() => service.search(query), onData: (result) {});
  ///
  /// // Wait for the current task to complete
  /// await latest.waitForCurrentTask();
  /// print('Current task completed');
  /// ```
  Future<void> waitForCurrentTask() {
    // If no task is running, return completed future
    if (!isRunning) {
      return Future.value();
    }

    // If there's a debounce completer, return its future
    if (_debounceCompleter != null && !_debounceCompleter!.isCompleted) {
      return _debounceCompleter!.future;
    }

    // Create a new completer that will complete when the task finishes
    final completer = Completer<void>();
    _waitingCompleters.add(completer);

    return completer.future;
  }

  /// Helper method to complete all waiting completers and clear the list
  void _completeWaitingCompleters() {
    for (final completer in _waitingCompleters) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _waitingCompleters.clear();
  }
}
