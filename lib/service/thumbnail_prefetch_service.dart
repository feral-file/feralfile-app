//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/model/thumbnail_cache_entry.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/thumbnail_disk_cache.dart';
import 'package:autonomy_flutter/util/thumbnail_fetcher.dart';
import 'package:autonomy_flutter/util/thumbnail_url_parser.dart';
import 'package:sentry/sentry.dart';

/// Priority lanes for thumbnail prefetching
enum PrefetchPriority {
  visible(0, 12), // Highest priority, currently visible
  ahead(1, 20), // Ahead of scroll position
  behind(2, 8), // Behind scroll position
  backgroundWarm(3, 8); // Background/DB warm-up

  const PrefetchPriority(this.level, this.quota);

  final int level;
  final int quota; // Max concurrent tasks for this lane
}

/// Thumbnail update notification
class ThumbnailUpdate {
  const ThumbnailUpdate({
    required this.originKey,
    required this.variant,
    required this.status,
  });

  final String originKey;
  final String variant;
  final int status;
}

/// Target size for thumbnail prefetch
class ThumbnailSize {
  const ThumbnailSize({
    required this.widthPx,
    required this.heightPx,
  });

  final int widthPx;
  final int heightPx;
}

/// Prefetch request specification
class _PrefetchTask {
  _PrefetchTask({
    required this.url,
    required this.key,
    required this.originKey,
    required this.variant,
    required this.priority,
    required this.targetSize,
  });

  final String url;
  final String key;
  final String originKey;
  final String variant;
  final PrefetchPriority priority;
  final ThumbnailSize? targetSize;
  ThumbnailFetchHandle? handle;
  bool isInFlight = false;
}

/// Central service for thumbnail prefetching with concurrency control
class ThumbnailPrefetchService {
  ThumbnailPrefetchService({
    required this.diskCache,
    required this.httpFetcher,
  });

  final ThumbnailDiskCache diskCache;
  final DartHttpThumbnailFetcher httpFetcher;

  // Update stream for widget rebuild notifications
  final _updateController = StreamController<ThumbnailUpdate>.broadcast();
  Stream<ThumbnailUpdate> get updates => _updateController.stream;

  // Task management
  final Map<String, _PrefetchTask> _tasks = {};
  final Map<PrefetchPriority, int> _inFlightCount = {};
  static const int kMaxInFlightTotal = 8; // Parallel downloads and resizes

  // Desired window (set by UI scroll prediction)
  final Set<String> _desiredKeys = {};

  // Persistent desired keys (from widget-initiated prefetch)
  final Set<String> _persistentKeys = {};

  bool _isProcessing = false;
  bool _initialized = false;

  /// Initialize service and clear any stale state
  Future<void> initialize() async {
    if (_initialized) {
      log.info('[ThumbnailPrefetchService] Already initialized, skipping');
      return;
    }

    log.info(
      '[ThumbnailPrefetchService] ===== INITIALIZING =====\n'
      'Stale state before clear:\n'
      '  - Tasks: ${_tasks.length}\n'
      '  - In-flight counts: $_inFlightCount\n'
      '  - Desired keys: ${_desiredKeys.length}\n'
      '  - Persistent keys: ${_persistentKeys.length}\n'
      '  - Is processing: $_isProcessing',
    );

    // Clear any stale in-flight counts from previous sessions
    _inFlightCount.clear();
    _tasks.clear();
    _desiredKeys.clear();
    _persistentKeys.clear();
    _isProcessing = false;

    _initialized = true;
    log.info(
      '[ThumbnailPrefetchService] ===== INITIALIZATION COMPLETE =====',
    );
  }

  /// Set the desired window of keys to prefetch
  /// This is the primary API for scroll-based prediction
  Future<void> setDesiredWindow(
    Set<String> keys,
    PrefetchPriority priority, {
    ThumbnailSize? targetSize,
  }) async {
    // Ensure initialized
    await initialize();

    // Update desired set (no cancellation - let tasks complete)
    _desiredKeys
      ..clear()
      ..addAll(keys);

    // Add new tasks
    for (final key in keys) {
      if (!_tasks.containsKey(key)) {
        // Parse key to get URL info
        // Key format: "originKey|variant"
        final parts = key.split('|');
        if (parts.length == 2) {
          final originKey = parts[0];
          final variant = parts[1];
          final url = variant == 'original'
              ? originKey
              : ThumbnailUrlParser.buildCloudflareUrl(originKey, variant);

          _tasks[key] = _PrefetchTask(
            url: url,
            key: key,
            originKey: originKey,
            variant: variant,
            priority: priority,
            targetSize: targetSize,
          );
        }
      }
    }

    // Trigger processing
    _processQueue();
  }

  /// Prefetch specific URLs (one-shot API)
  /// Adds to persistent set to prevent cancellation by scroll windows
  Future<void> prefetchUrls({
    required List<String> urls,
    ThumbnailSize? targetSize,
    PrefetchPriority priority = PrefetchPriority.backgroundWarm,
    bool persistent = true,
  }) async {
    // Ensure initialized
    await initialize();

    log.info(
      '[ThumbnailPrefetchService] prefetchUrls called with ${urls.length} URLs, '
      'priority=${priority.name}, targetSize=${targetSize?.widthPx}x${targetSize?.heightPx}',
    );

    for (final url in urls) {
      final parsed = ThumbnailUrlParser.parse(url);
      // Use ThumbnailCacheKey for consistent key generation
      final key = ThumbnailCacheKey.original(url);

      log.info('[ThumbnailPrefetchService] URL: $url -> Key: $key');

      // Add to persistent set if this is a widget-initiated request
      if (persistent && priority == PrefetchPriority.visible) {
        _persistentKeys.add(key);

        // Remove from persistent after completion or timeout
        Future<void>.delayed(const Duration(seconds: 30), () {
          _persistentKeys.remove(key);
        });
      }

      if (!_tasks.containsKey(key)) {
        log.info('[ThumbnailPrefetchService] Creating new task for: $key');
        _tasks[key] = _PrefetchTask(
          url: url,
          key: key,
          originKey: parsed.originKey,
          variant: parsed.variant,
          priority: priority,
          targetSize: targetSize,
        );
      } else {
        log.info('[ThumbnailPrefetchService] Task already exists for: $key');
      }
    }

    log.info('[ThumbnailPrefetchService] Total tasks: ${_tasks.length}');
    _processQueue();
  }

  /// Prefetch thumbnails from DP1NowDisplayingItems
  Future<void> prefetchNowDisplayingItems({
    required List<DP1NowDisplayingItem> items,
    ThumbnailSize? targetSize,
    PrefetchPriority priority = PrefetchPriority.backgroundWarm,
  }) async {
    final urls = <String>[];
    for (final item in items) {
      final thumbnailUri = item.thumbnail?.uri;
      if (thumbnailUri != null && thumbnailUri.isNotEmpty) {
        urls.add(thumbnailUri);
      }
    }

    await prefetchUrls(
      urls: urls,
      targetSize: targetSize,
      priority: priority,
    );
  }

  /// Cancel specific tasks (deprecated - tasks now run to completion)
  void cancelTasks(Set<String> keys) {
    // No-op: tasks are allowed to complete naturally
    // Keeping method for API compatibility
  }

  /// Process the queue with priority and concurrency control
  void _processQueue() {
    log.info(
      '[ThumbnailPrefetchService] _processQueue called, '
      'isProcessing=$_isProcessing, tasks=${_tasks.length}',
    );

    if (_isProcessing) {
      log.info('[ThumbnailPrefetchService] Already processing, skipping');
      return; // Already processing
    }

    _isProcessing = true;
    log.info('[ThumbnailPrefetchService] Starting _runQueue...');
    unawaited(_runQueue());
  }

  Future<void> _runQueue() async {
    log.info('[ThumbnailPrefetchService] _runQueue executing...');

    try {
      while (true) {
        // Yield to event loop to prevent UI blocking
        await Future<void>.delayed(Duration.zero);

        // Check total in-flight limit
        final totalInFlight =
            _inFlightCount.values.fold<int>(0, (sum, count) => sum + count);

        if (totalInFlight >= kMaxInFlightTotal) {
          log.info(
            '[ThumbnailPrefetchService] At capacity ($totalInFlight/$kMaxInFlightTotal), '
            'exiting queue',
          );
          break;
        }

        // Find next task to execute (highest priority with available quota)
        _PrefetchTask? nextTask;
        for (final priority in PrefetchPriority.values) {
          final inFlight = _inFlightCount[priority] ?? 0;
          if (inFlight >= priority.quota) {
            continue; // This lane is full
          }

          // Find a task in this priority that's not in flight
          nextTask = _tasks.values.firstWhere(
            (task) => task.priority == priority && !task.isInFlight,
            orElse: () => _PrefetchTask(
              url: '',
              key: '',
              originKey: '',
              variant: '',
              priority: priority,
              targetSize: null,
            ),
          );

          if (nextTask.key.isNotEmpty) {
            break; // Found a task
          }
        }

        if (nextTask == null || nextTask.key.isEmpty) {
          log.info('[ThumbnailPrefetchService] No available tasks, exiting');
          break;
        }

        // Check if already in cache
        final entry = diskCache.getByKey(nextTask.key);
        if (entry != null && entry.status == ThumbnailStatus.ready) {
          // Already cached, remove from queue
          _tasks.remove(nextTask.key);
          continue;
        }

        log.info(
          '[ThumbnailPrefetchService] Starting task: ${nextTask.key} '
          '(${nextTask.priority.name}, $totalInFlight/$kMaxInFlightTotal in-flight)',
        );

        // Start the task
        unawaited(_executeTask(nextTask));
      }
    } catch (e, stackTrace) {
      log.severe('[ThumbnailPrefetchService] CRITICAL: _runQueue crashed: $e');
      log.severe('[ThumbnailPrefetchService] Stack trace: $stackTrace');
    } finally {
      log.info('[ThumbnailPrefetchService] _runQueue finally block');
      _isProcessing = false;
      log.info('[ThumbnailPrefetchService] _runQueue finished');

      // If there are still tasks, schedule another run
      try {
        final pendingTasks =
            _tasks.values.where((task) => !task.isInFlight).length;
        log.info('[ThumbnailPrefetchService] Pending tasks: $pendingTasks');

        if (pendingTasks > 0) {
          log.info('[ThumbnailPrefetchService] Scheduling next queue run...');
          Future.delayed(const Duration(milliseconds: 100), _processQueue);
        }
      } catch (e) {
        log.severe('[ThumbnailPrefetchService] Error in finally block: $e');
      }
    }
  }

  Future<void> _executeTask(_PrefetchTask task) async {
    log.info('[ThumbnailPrefetchService] _executeTask START: ${task.key}');

    task.isInFlight = true;
    task.handle = ThumbnailFetchHandle(Completer<void>());
    _inFlightCount[task.priority] = (_inFlightCount[task.priority] ?? 0) + 1;

    final totalInFlight =
        _inFlightCount.values.fold<int>(0, (sum, count) => sum + count);
    log.info(
        '[ThumbnailPrefetchService] Starting task (${task.priority.name}): $totalInFlight/$kMaxInFlightTotal in-flight');

    try {
      log.info('[ThumbnailPrefetchService] Creating ThumbnailFetcher...');
      final fetcher = ThumbnailFetcher(
        diskCache: diskCache,
        httpFetcher: httpFetcher,
      );

      log.info(
          '[ThumbnailPrefetchService] Calling fetchThumbnail for: ${task.url}');
      final result = await fetcher.fetchThumbnail(
        url: task.url,
        handle: task.handle!,
        targetWidth: task.targetSize?.widthPx,
        targetHeight: task.targetSize?.heightPx,
      );

      log.info(
          '[ThumbnailPrefetchService] fetchThumbnail returned, success: ${result.success}');

      // Notify listeners if successful (async to prevent Navigator deadlock)
      if (result.success) {
        Future.microtask(() {
          _updateController.add(
            ThumbnailUpdate(
              originKey: task.originKey,
              variant: task.variant,
              status: ThumbnailStatus.ready,
            ),
          );
        });
      }
    } catch (e, stackTrace) {
      log.severe(
          '[ThumbnailPrefetchService] Error executing task ${task.key}: $e');
      log.severe('[ThumbnailPrefetchService] Stack trace: $stackTrace');
      unawaited(
        Sentry.captureException(
          'ThumbnailPrefetchService task error: $e',
          stackTrace: stackTrace,
        ),
      );
    } finally {
      log.info(
          '[ThumbnailPrefetchService] _executeTask FINALLY for: ${task.key}');
      _inFlightCount[task.priority] = (_inFlightCount[task.priority] ?? 1) - 1;
      _tasks.remove(task.key);
      task.isInFlight = false;

      final totalInFlight =
          _inFlightCount.values.fold<int>(0, (sum, count) => sum + count);
      log.info(
          '[ThumbnailPrefetchService] Task completed: $totalInFlight/$kMaxInFlightTotal in-flight');

      // Trigger next batch
      log.info('[ThumbnailPrefetchService] Triggering next batch...');
      _processQueue();
    }
  }

  /// Get current queue status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'total_tasks': _tasks.length,
      'in_flight_by_priority': _inFlightCount,
      'desired_window_size': _desiredKeys.length,
    };
  }

  /// Dispose resources
  void dispose() {
    _updateController.close();
    _tasks.clear();
    _inFlightCount.clear();
    _desiredKeys.clear();
    _persistentKeys.clear();
  }
}
