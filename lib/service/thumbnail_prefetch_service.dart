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
import 'package:synchronized/synchronized.dart';

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

  // Dual queue system: high priority and low priority
  final Map<String, _PrefetchTask> _highQueue = {};
  final Map<String, _PrefetchTask> _lowQueue = {};
  final _queueLock = Lock();

  // In-flight tracking
  final Map<PrefetchPriority, int> _inFlightCount = {};
  final Set<String> _inFlightKeys = {}; // Track which keys are being processed
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
      '  - High queue: ${_highQueue.length}\n'
      '  - Low queue: ${_lowQueue.length}\n'
      '  - In-flight counts: $_inFlightCount\n'
      '  - Desired keys: ${_desiredKeys.length}\n'
      '  - Persistent keys: ${_persistentKeys.length}\n'
      '  - Is processing: $_isProcessing',
    );

    // Clear any stale in-flight counts from previous sessions
    await _queueLock.synchronized(() {
      _inFlightCount.clear();
      _inFlightKeys.clear();
      _highQueue.clear();
      _lowQueue.clear();
      _desiredKeys.clear();
      _persistentKeys.clear();
      _isProcessing = false;
    });

    _initialized = true;
  }

  /// Add task to high priority queue
  /// If task exists in low queue, remove it from there
  Future<void> _addToHighQueue(_PrefetchTask task) async {
    await _queueLock.synchronized(() {
      // Remove from low queue if it exists there
      if (_lowQueue.containsKey(task.key)) {
        log.info(
          '[ThumbnailPrefetchService] Moving ${task.key} from low to high queue',
        );
        _lowQueue.remove(task.key);
      }

      // Add to high queue if not already there
      if (!_highQueue.containsKey(task.key)) {
        _highQueue[task.key] = task;
        log.info(
          '[ThumbnailPrefetchService] Added ${task.key} to high queue',
        );
      }
    });
  }

  /// Add task to low priority queue
  /// Only add if it doesn't exist in high queue
  Future<void> _addToLowQueue(_PrefetchTask task) async {
    await _queueLock.synchronized(() {
      // Don't add if already in high queue
      if (_highQueue.containsKey(task.key)) {
        log.info(
          '[ThumbnailPrefetchService] Skipping ${task.key} - already in high queue',
        );
        return;
      }

      // Add to low queue if not already there
      if (!_lowQueue.containsKey(task.key)) {
        _lowQueue[task.key] = task;
        log.info(
          '[ThumbnailPrefetchService] Added ${task.key} to low queue',
        );
      }
    });
  }

  /// Remove task from both queues
  Future<void> _removeFromQueues(String key) async {
    await _queueLock.synchronized(() {
      _highQueue.remove(key);
      _lowQueue.remove(key);
    });
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

    // Add new tasks to high queue (visible items get high priority)
    for (final key in keys) {
      final alreadyExists = await _queueLock.synchronized(() {
        return _highQueue.containsKey(key) || _lowQueue.containsKey(key);
      });

      if (!alreadyExists) {
        // Parse key to get URL info
        // Key format: "originKey|variant"
        final parts = key.split('|');
        if (parts.length == 2) {
          final originKey = parts[0];
          final variant = parts[1];
          final url = variant == 'original'
              ? originKey
              : ThumbnailUrlParser.buildCloudflareUrl(originKey, variant);

          final task = _PrefetchTask(
            url: url,
            key: key,
            originKey: originKey,
            variant: variant,
            priority: priority,
            targetSize: targetSize,
          );

          // Add to high queue (visible items)
          await _addToHighQueue(task);
        }
      }
    }

    // Trigger processing
    _processQueue();
  }

  /// Prefetch specific URLs (one-shot API)
  /// Adds to persistent set to prevent cancellation by scroll windows
  /// Use [highPriority] to add to high queue (for immediate display)
  Future<void> prefetchUrls({
    required List<String> urls,
    ThumbnailSize? targetSize,
    PrefetchPriority priority = PrefetchPriority.backgroundWarm,
    bool persistent = true,
    bool highPriority = false,
  }) async {
    // Ensure initialized
    await initialize();

    log.info(
      '[ThumbnailPrefetchService] prefetchUrls called with ${urls.length} URLs, '
      'priority=${priority.name}, highPriority=$highPriority, '
      'targetSize=${targetSize?.widthPx}x${targetSize?.heightPx}',
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

      final alreadyExists = await _queueLock.synchronized(() {
        return _highQueue.containsKey(key) || _lowQueue.containsKey(key);
      });

      if (!alreadyExists) {
        log.info('[ThumbnailPrefetchService] Creating new task for: $key');
        final task = _PrefetchTask(
          url: url,
          key: key,
          originKey: parsed.originKey,
          variant: parsed.variant,
          priority: priority,
          targetSize: targetSize,
        );

        // Add to appropriate queue based on highPriority flag
        if (highPriority) {
          await _addToHighQueue(task);
        } else {
          await _addToLowQueue(task);
        }
      } else {
        log.info('[ThumbnailPrefetchService] Task already exists for: $key');
      }
    }

    final queueInfo = await _queueLock.synchronized(() {
      return {
        'high': _highQueue.length,
        'low': _lowQueue.length,
      };
    });
    log.info(
      '[ThumbnailPrefetchService] Total tasks: high=${queueInfo['high']}, low=${queueInfo['low']}',
    );
    _processQueue();
  }

  /// Prefetch thumbnails from DP1NowDisplayingItems
  /// If [highPriorityCount] is set, first N items go to high queue
  Future<void> prefetchNowDisplayingItems({
    required List<DP1NowDisplayingItem> items,
    ThumbnailSize? targetSize,
    PrefetchPriority priority = PrefetchPriority.backgroundWarm,
    int? highPriorityCount,
  }) async {
    final urls = <String>[];
    for (final item in items) {
      final thumbnailUri = item.thumbnail?.uri;
      if (thumbnailUri != null && thumbnailUri.isNotEmpty) {
        urls.add(thumbnailUri);
      }
    }

    // If highPriorityCount is specified, split urls into high and low priority
    if (highPriorityCount != null && highPriorityCount > 0) {
      final highPriorityUrls = urls.take(highPriorityCount).toList();
      final lowPriorityUrls = urls.length > highPriorityCount
          ? urls.skip(highPriorityCount).toList()
          : <String>[];

      // Prefetch high priority items first
      if (highPriorityUrls.isNotEmpty) {
        await prefetchUrls(
          urls: highPriorityUrls,
          targetSize: targetSize,
          priority: priority,
          highPriority: true,
        );
      }

      // Then prefetch low priority items
      if (lowPriorityUrls.isNotEmpty) {
        await prefetchUrls(
          urls: lowPriorityUrls,
          targetSize: targetSize,
          priority: priority,
          highPriority: false,
        );
      }
    } else {
      // No split, add all to low priority by default
      await prefetchUrls(
        urls: urls,
        targetSize: targetSize,
        priority: priority,
        highPriority: false,
      );
    }
  }

  /// Cancel specific tasks (deprecated - tasks now run to completion)
  void cancelTasks(Set<String> keys) {
    // No-op: tasks are allowed to complete naturally
    // Keeping method for API compatibility
  }

  /// Process the queue with priority and concurrency control
  void _processQueue() {
    if (_isProcessing) {
      return; // Already processing
    }

    _isProcessing = true;
    unawaited(_runQueue());
  }

  Future<void> _runQueue() async {
    try {
      while (true) {
        // Yield to event loop to prevent UI blocking
        await Future<void>.delayed(Duration.zero);

        // Check total in-flight limit
        final totalInFlight =
            _inFlightCount.values.fold<int>(0, (sum, count) => sum + count);

        if (totalInFlight >= kMaxInFlightTotal) {
          break;
        }

        // Find next task to execute
        // Priority: high queue first, then low queue
        _PrefetchTask? nextTask;

        await _queueLock.synchronized(() {
          // Try to get task from high queue first
          for (final priority in PrefetchPriority.values) {
            final inFlight = _inFlightCount[priority] ?? 0;
            if (inFlight >= priority.quota) {
              continue; // This lane is full
            }

            // Find a task in high queue with this priority that's not in flight
            for (final task in _highQueue.values) {
              if (task.priority == priority && !task.isInFlight) {
                nextTask = task;
                break;
              }
            }

            if (nextTask != null) {
              break; // Found a task in high queue
            }
          }

          // If no task in high queue, try low queue
          if (nextTask == null) {
            for (final priority in PrefetchPriority.values) {
              final inFlight = _inFlightCount[priority] ?? 0;
              if (inFlight >= priority.quota) {
                continue; // This lane is full
              }

              // Find a task in low queue with this priority that's not in flight
              for (final task in _lowQueue.values) {
                if (task.priority == priority && !task.isInFlight) {
                  nextTask = task;
                  break;
                }
              }

              if (nextTask != null) {
                break; // Found a task in low queue
              }
            }
          }
        });

        if (nextTask == null) {
          log.info('[ThumbnailPrefetchService] No available tasks, exiting');
          break;
        }

        // Check if already in-flight
        final isAlreadyInFlight = await _queueLock.synchronized(() {
          return _inFlightKeys.contains(nextTask!.key);
        });
        
        if (isAlreadyInFlight) {
          log.info(
            '[ThumbnailPrefetchService] Task ${nextTask!.key} already in-flight, skipping',
          );
          await _removeFromQueues(nextTask!.key);
          continue;
        }

        // Check if already in cache
        final entry = diskCache.getByKey(nextTask!.key);
        if (entry != null && entry.status == ThumbnailStatus.ready) {
          // Already cached, remove from queue
          await _removeFromQueues(nextTask!.key);
          continue;
        }

        // Start the task
        unawaited(_executeTask(nextTask!));
      }
    } catch (e) {
      log.severe('[ThumbnailPrefetchService] CRITICAL: _runQueue crashed: $e');
    } finally {
      log.info('[ThumbnailPrefetchService] _runQueue finally block');
      _isProcessing = false;
      log.info('[ThumbnailPrefetchService] _runQueue finished');

      // If there are still tasks, schedule another run
      try {
        final queueInfo = await _queueLock.synchronized(() {
          final highPending =
              _highQueue.values.where((task) => !task.isInFlight).length;
          final lowPending =
              _lowQueue.values.where((task) => !task.isInFlight).length;
          return {'high': highPending, 'low': lowPending};
        });

        final pendingTasks = (queueInfo['high'] ?? 0) + (queueInfo['low'] ?? 0);

        if (pendingTasks > 0) {
          Future.delayed(const Duration(milliseconds: 100), _processQueue);
        }
      } catch (e) {
        log.severe('[ThumbnailPrefetchService] Error in finally block: $e');
      }
    }
  }

  Future<void> _executeTask(_PrefetchTask task) async {
    task.isInFlight = true;
    task.handle = ThumbnailFetchHandle(Completer<void>());
    
    // Mark this key as in-flight
    await _queueLock.synchronized(() {
      _inFlightKeys.add(task.key);
      _inFlightCount[task.priority] = (_inFlightCount[task.priority] ?? 0) + 1;
    });

    try {
      final fetcher = ThumbnailFetcher(
        diskCache: diskCache,
        httpFetcher: httpFetcher,
      );

      final result = await fetcher.fetchThumbnail(
        url: task.url,
        handle: task.handle!,
        targetWidth: task.targetSize?.widthPx,
        targetHeight: task.targetSize?.heightPx,
      );

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
      await _queueLock.synchronized(() {
        _inFlightKeys.remove(task.key);
        _inFlightCount[task.priority] = (_inFlightCount[task.priority] ?? 1) - 1;
      });
      await _removeFromQueues(task.key);
      task.isInFlight = false;
      _processQueue();
    }
  }

  /// Get current queue status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'high_queue_size': _highQueue.length,
      'low_queue_size': _lowQueue.length,
      'total_tasks': _highQueue.length + _lowQueue.length,
      'in_flight_by_priority': _inFlightCount,
      'desired_window_size': _desiredKeys.length,
    };
  }

  /// Dispose resources
  void dispose() {
    _updateController.close();
    _highQueue.clear();
    _lowQueue.clear();
    _inFlightCount.clear();
    _inFlightKeys.clear();
    _desiredKeys.clear();
    _persistentKeys.clear();
  }
}
