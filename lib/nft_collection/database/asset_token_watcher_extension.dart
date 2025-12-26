//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/model/token.dart';
import 'package:rxdart/rxdart.dart';

/// Extension on Stream<List<AssetToken>> to add debouncing functionality.
/// This reduces the frequency of updates when database changes occur rapidly.
extension AssetTokenWatcherExtension<T> on Stream<T> {
  /// Debounces the stream to reduce update frequency when database changes occur.
  ///
  /// When multiple database changes happen in quick succession, this extension
  /// waits for a quiet period before emitting the latest value. This helps
  /// reduce unnecessary UI rebuilds and improve performance.
  ///
  /// [debounceDuration] - The duration to wait after the last event before
  /// emitting. Defaults to 300ms.
  ///
  /// Example:
  /// ```dart
  /// final watcher = AssetTokenCidsWatcher(cids: cids);
  /// watcher.watch().watchWithBouncing(debounceDuration: Duration(milliseconds: 300))
  ///   .listen((tokens) {
  ///     // Handle updated tokens
  ///   });
  /// ```
  Stream<T> watchWithBouncing({
    Duration debounceDuration = const Duration(milliseconds: 300),
  }) {
    return this.debounceTime(debounceDuration);
  }
}
