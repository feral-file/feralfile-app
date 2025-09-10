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
          _maxWaitTimer?.cancel();
          _maxWaitTimer = null;
          if (!completer.isCompleted) completer.complete();
        }
      }

      _debounceTimer = Timer(debounce, execute);

      // Ensure task runs at most after maxWait even if new calls keep arriving
      if (maxWait != null && maxWait.inMilliseconds > 0) {
        _maxWaitTimer ??= Timer(maxWait, () {
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
  }
}
