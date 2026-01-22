//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/database.dart';
import 'package:autonomy_flutter/model/thumbnail_cache_entry.dart';
import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/thumbnail_url_parser.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';
import 'package:synchronized/synchronized.dart';

/// Custom thumbnail disk cache with LRU + TTL eviction
/// Manages both file storage and ObjectBox metadata
class ThumbnailDiskCache {
  factory ThumbnailDiskCache() => _instance;

  ThumbnailDiskCache._();

  static final ThumbnailDiskCache _instance = ThumbnailDiskCache._();

  String? _cacheDir;
  Box<ThumbnailCacheEntry>? _box;
  
  // Per-key locks to prevent concurrent writes to the same file
  final Map<String, Lock> _writeLocks = {};

  // Configuration (tunable)
  static const int kMaxDiskSizeBytes = 500 * 1024 * 1024; // 500 MB
  static const int kTtlDays = 14; // 14 days
  static const int kStaleDownloadMs = 30 * 60 * 1000; // 30 minutes

  /// Initialize cache directory and ObjectBox box
  Future<void> initialize() async {
    if (_cacheDir != null && _box != null) {
      return; // Already initialized
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = p.join(tempDir.path, 'thumbnail_cache');
      await Directory(_cacheDir!).create(recursive: true);

      _box = ObjectBox.store.box<ThumbnailCacheEntry>();

      log.info('[ThumbnailDiskCache] Initialized at: $_cacheDir');

      // Run startup sweep to cleanup stale state
      await _startupSweep();
    } catch (e, stackTrace) {
      log.severe('[ThumbnailDiskCache] Error initializing: $e');
      unawaited(
        Sentry.captureException(
          'ThumbnailDiskCache initialization error: $e',
          stackTrace: stackTrace,
        ),
      );
      rethrow;
    }
  }

  /// Get ObjectBox box (throw if not initialized)
  Box<ThumbnailCacheEntry> get _boxOrThrow {
    if (_box == null) {
      throw StateError(
        'ThumbnailDiskCache not initialized. Call initialize() first.',
      );
    }
    return _box!;
  }

  /// Get cache directory (throw if not initialized)
  String get _cacheDirOrThrow {
    if (_cacheDir == null) {
      throw StateError(
        'ThumbnailDiskCache not initialized. Call initialize() first.',
      );
    }
    return _cacheDir!;
  }

  /// Startup sweep: cleanup stale downloading states and orphaned files
  Future<void> _startupSweep() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final staleDownloadThreshold = now - kStaleDownloadMs;

      // Find stale "downloading" entries (app crashed while downloading)
      final query = _boxOrThrow
          .query(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.downloading))
          .build();
      final staleEntries = query.find();
      query.close();

      for (final entry in staleEntries) {
        // If downloading for too long, mark as missing
        if (entry.lastAccessAtMs < staleDownloadThreshold) {
          log.info(
            '[ThumbnailDiskCache] Marking stale downloading entry as missing: ${entry.key}',
          );
          entry.status = ThumbnailStatus.missing;
          entry.inFlightBackend = null;
          entry.inFlightTaskId = null;
          _boxOrThrow.put(entry);
        }
      }

      // Cleanup orphaned files (files without ObjectBox entry)
      await _cleanupOrphanedFiles();

      // Purge expired entries
      await purgeExpired();

      log.info('[ThumbnailDiskCache] Startup sweep completed');
    } catch (e, stackTrace) {
      log.severe('[ThumbnailDiskCache] Error in startup sweep: $e');
      unawaited(
        Sentry.captureException(
          'ThumbnailDiskCache startup sweep error: $e',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Cleanup orphaned files (exist on disk but not in ObjectBox)
  Future<void> _cleanupOrphanedFiles() async {
    try {
      final cacheDir = Directory(_cacheDirOrThrow);
      if (!await cacheDir.exists()) {
        return;
      }

      final files = await cacheDir.list().toList();
      for (final file in files) {
        if (file is File) {
          final fileName = p.basename(file.path);
          // Check if this file has a corresponding ObjectBox entry
          final query =
              _boxOrThrow.query(ThumbnailCacheEntry_.localPath.equals(fileName)).build();
          final entries = query.find();
          query.close();

          if (entries.isEmpty) {
            // Orphaned file - delete it
            try {
              await file.delete();
              log.info(
                '[ThumbnailDiskCache] Deleted orphaned file: $fileName',
              );
            } catch (e) {
              log.info(
                '[ThumbnailDiskCache] Error deleting orphaned file $fileName: $e',
              );
            }
          }
        }
      }
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error cleaning orphaned files: $e');
    }
  }

  /// Get entry by key
  ThumbnailCacheEntry? getByKey(String key) {
    try {
      final query = _boxOrThrow.query(ThumbnailCacheEntry_.key.equals(key)).build();
      final entry = query.findFirst();
      query.close();
      return entry;
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error getting entry by key: $e');
      return null;
    }
  }

  /// Find best available variant for an originKey
  /// Returns the highest variantRank <= requestedRank that is ready
  ThumbnailCacheEntry? getBestAvailableVariant(
    String originKey,
    int requestedRank,
  ) {
    try {
      final query = _boxOrThrow
          .query(ThumbnailCacheEntry_.originKey
              .equals(originKey)
              .and(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.ready))
              .and(ThumbnailCacheEntry_.variantRank.lessOrEqual(requestedRank)))
          .order(ThumbnailCacheEntry_.variantRank, flags: Order.descending)
          .build();
      final entry = query.findFirst();
      query.close();

      if (entry != null) {
        // Touch access time for LRU
        updateAccessTime(entry.key);
      }

      return entry;
    } catch (e) {
      log.severe(
        '[ThumbnailDiskCache] Error getting best available variant: $e',
      );
      return null;
    }
  }

  /// Put or update entry
  void put(ThumbnailCacheEntry entry) {
    try {
      _boxOrThrow.put(entry);
    } catch (e, stackTrace) {
      log.severe('[ThumbnailDiskCache] Error putting entry: $e');
      unawaited(
        Sentry.captureException(
          'ThumbnailDiskCache put error: $e',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Update access time for LRU
  void updateAccessTime(String key) {
    try {
      final entry = getByKey(key);
      if (entry != null) {
        entry.lastAccessAtMs = DateTime.now().millisecondsSinceEpoch;
        _boxOrThrow.put(entry);
      }
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error updating access time: $e');
    }
  }

  /// Find original file entry for a URL
  ThumbnailCacheEntry? getOriginal(String url) {
    try {
      final key = ThumbnailCacheKey.original(url);
      final entry = getByKey(key);
      if (entry != null &&
          entry.status == ThumbnailStatus.ready &&
          entry.isOriginal) {
        updateAccessTime(key);
        return entry;
      }
      return null;
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error getting original: $e');
      return null;
    }
  }

  /// Find cached resize with similar dimensions (within 20% margin)
  ThumbnailCacheEntry? getSimilarSize(String url, int width, int height) {
    try {
      // Get all resized entries for this URL
      final urlPrefix = '$url|';
      final query = _boxOrThrow
          .query(ThumbnailCacheEntry_.key
              .startsWith(urlPrefix)
              .and(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.ready))
              .and(ThumbnailCacheEntry_.isOriginal.equals(false)))
          .build();
      final entries = query.find();
      query.close();

      // Find closest match within 20% margin
      ThumbnailCacheEntry? bestMatch;
      var bestScore = double.infinity;
      const margin = 0.2; // 20% margin

      for (final entry in entries) {
        if (entry.imageWidth == null || entry.imageHeight == null) {
          continue;
        }

        final widthDiff = (entry.imageWidth! - width).abs() / width;
        final heightDiff = (entry.imageHeight! - height).abs() / height;
        final maxDiff = widthDiff > heightDiff ? widthDiff : heightDiff;

        if (maxDiff <= margin) {
          // Within margin, calculate score (prefer exact matches)
          final score = widthDiff + heightDiff;
          if (score < bestScore) {
            bestScore = score;
            bestMatch = entry;
          }
        }
      }

      if (bestMatch != null) {
        updateAccessTime(bestMatch.key);
        log.info(
          '[ThumbnailDiskCache] Found similar size: '
          '${bestMatch.imageWidth}x${bestMatch.imageHeight} '
          'for requested ${width}x$height',
        );
      }

      return bestMatch;
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error finding similar size: $e');
      return null;
    }
  }

  /// Find exact size match
  ThumbnailCacheEntry? getExactSize(String url, int width, int height) {
    try {
      final key = ThumbnailCacheKey.resized(url, width, height);
      final entry = getByKey(key);
      if (entry != null && entry.status == ThumbnailStatus.ready) {
        updateAccessTime(key);
        return entry;
      }
      return null;
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error getting exact size: $e');
      return null;
    }
  }

  /// Read file from disk
  File? readFile(String key) {
    try {
      final entry = getByKey(key);
      if (entry == null ||
          entry.status != ThumbnailStatus.ready ||
          entry.localPath == null) {
        return null;
      }

      final filePath = p.join(_cacheDirOrThrow, entry.localPath!);
      final file = File(filePath);

      if (!file.existsSync()) {
        // File missing - mark entry as missing
        log.info(
          '[ThumbnailDiskCache] File missing for key $key, marking as missing',
        );
        entry.status = ThumbnailStatus.missing;
        entry.localPath = null;
        _boxOrThrow.put(entry);
        return null;
      }

      // Touch access time
      updateAccessTime(key);
      return file;
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error reading file: $e');
      return null;
    }
  }

  /// Get full path for a local filename
  String getFullPath(String localPath) {
    return p.join(_cacheDirOrThrow, localPath);
  }

  /// Get or create lock for a specific key
  Lock _getLock(String key) {
    return _writeLocks.putIfAbsent(key, () => Lock());
  }

  /// Write file using atomic temp-then-commit pattern
  /// Uses per-key locking to prevent race conditions
  Future<void> writeTempThenCommit(
    String key,
    List<int> bytes, {
    String? etag,
    String? lastModified,
    bool isOriginal = false,
    int? imageWidth,
    int? imageHeight,
  }) async {
    final lock = _getLock(key);
    
    return lock.synchronized(() async {
      try {
        // Check if already cached (another task might have written it)
        final existingEntry = getByKey(key);
        if (existingEntry != null && existingEntry.status == ThumbnailStatus.ready) {
          log.info(
            '[ThumbnailDiskCache] File already cached for key: $key, skipping write',
          );
          return;
        }

        final fileName = '${md5.convert(key.codeUnits)}.bin';
        final targetPath = p.join(_cacheDirOrThrow, fileName);
        final tempPath = '$targetPath.tmp';

        // Check if target file already exists
        final targetFile = File(targetPath);
        if (await targetFile.exists()) {
          log.info(
            '[ThumbnailDiskCache] Target file already exists for key: $key, '
            'updating metadata only',
          );
          // File exists, just update metadata
          await _updateMetadata(
            key: key,
            fileName: fileName,
            bytes: bytes,
            etag: etag,
            lastModified: lastModified,
            isOriginal: isOriginal,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
          );
          return;
        }

        // Write to temp file
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(bytes);

        // Atomic rename
        try {
          await tempFile.rename(targetPath);
        } catch (e) {
          // If rename fails, check if target was created by another task
          if (await targetFile.exists()) {
            log.info(
              '[ThumbnailDiskCache] Target file appeared during rename for key: $key, '
              'cleaning up temp file',
            );
            // Clean up temp file
            if (await tempFile.exists()) {
              await tempFile.delete();
            }
            // Update metadata for existing file
            await _updateMetadata(
              key: key,
              fileName: fileName,
              bytes: bytes,
              etag: etag,
              lastModified: lastModified,
              isOriginal: isOriginal,
              imageWidth: imageWidth,
              imageHeight: imageHeight,
            );
            return;
          }
          rethrow;
        }

        // Update or create ObjectBox entry
        await _updateMetadata(
          key: key,
          fileName: fileName,
          bytes: bytes,
          etag: etag,
          lastModified: lastModified,
          isOriginal: isOriginal,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );

        log.info(
          '[ThumbnailDiskCache] Wrote file for key: $key '
          '(${bytes.length} bytes, original=$isOriginal, '
          'size=${imageWidth ?? 0}x${imageHeight ?? 0})',
        );
      } catch (e, stackTrace) {
        log.severe('[ThumbnailDiskCache] Error writing file for key $key: $e');
        unawaited(
          Sentry.captureException(
            'ThumbnailDiskCache write error: $e',
            stackTrace: stackTrace,
          ),
        );
        rethrow;
      }
    });
  }

  /// Update metadata for a cached file
  Future<void> _updateMetadata({
    required String key,
    required String fileName,
    required List<int> bytes,
    String? etag,
    String? lastModified,
    bool isOriginal = false,
    int? imageWidth,
    int? imageHeight,
  }) async {
    var entry = getByKey(key);
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (entry != null) {
      // Update existing entry
      entry.status = ThumbnailStatus.ready;
      entry.localPath = fileName;
      entry.sizeBytes = bytes.length;
      entry.imageWidth = imageWidth;
      entry.imageHeight = imageHeight;
      entry.isOriginal = isOriginal;
      entry.variant = isOriginal ? 'original' : 'resized';
      // Keep existing variantRank or set to high value for resized
      if (!isOriginal && entry.variantRank == 0) {
        entry.variantRank = 99; // High rank so it's preferred
      }
      entry.lastAccessAtMs = now;
      entry.expiresAtMs = now + (kTtlDays * 24 * 60 * 60 * 1000);
      entry.etag = etag;
      entry.lastModified = lastModified;
      entry.inFlightBackend = null;
      entry.inFlightTaskId = null;
      entry.errorCount = 0;
      entry.lastError = null;
      _boxOrThrow.put(entry);
    } else {
      // Create new entry
      final parsed = ThumbnailCacheKey.parse(key);
      final url = parsed['url'] as String;
      
      // Use ThumbnailUrlParser to get proper originKey for compatibility
      final urlParsed = ThumbnailUrlParser.parse(url);
      
      entry = ThumbnailCacheEntry(
        key: key,
        originKey: urlParsed.originKey,
        variant: isOriginal ? 'original' : 'resized',
        // Original gets rank 0, resized gets high rank so it's preferred
        variantRank: isOriginal ? VariantRank.getRank('original') : 99,
        url: url,
        status: ThumbnailStatus.ready,
        localPath: fileName,
        sizeBytes: bytes.length,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        isOriginal: isOriginal,
        createdAtMs: now,
        lastAccessAtMs: now,
        expiresAtMs: now + (kTtlDays * 24 * 60 * 60 * 1000),
        etag: etag,
        lastModified: lastModified,
      );
      _boxOrThrow.put(entry);
    }
  }

  /// Delete file from disk and update entry
  Future<void> deleteFile(String key) async {
    try {
      final entry = getByKey(key);
      if (entry?.localPath != null) {
        final filePath = p.join(_cacheDirOrThrow, entry!.localPath!);
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (entry != null) {
        entry.status = ThumbnailStatus.evicted;
        entry.localPath = null;
        entry.sizeBytes = null;
        _boxOrThrow.put(entry);
      }
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error deleting file: $e');
    }
  }

  /// Purge expired entries based on TTL
  Future<void> purgeExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final query = _boxOrThrow
          .query(ThumbnailCacheEntry_.expiresAtMs.notNull().and(
                ThumbnailCacheEntry_.expiresAtMs.lessOrEqual(now),
              ))
          .build();
      final expiredEntries = query.find();
      query.close();

      for (final entry in expiredEntries) {
        log.info('[ThumbnailDiskCache] Purging expired entry: ${entry.key}');
        await deleteFile(entry.key);
      }

      log.info('[ThumbnailDiskCache] Purged ${expiredEntries.length} expired entries');
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error purging expired entries: $e');
    }
  }

  /// Evict entries to stay under max disk size using LRU
  Future<void> evictIfNeeded() async {
    try {
      // Calculate total size of ready entries
      final query = _boxOrThrow
          .query(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.ready))
          .build();
      final readyEntries = query.find();
      query.close();

      final totalSize = readyEntries.fold<int>(
        0,
        (sum, entry) => sum + (entry.sizeBytes ?? 0),
      );

      if (totalSize <= kMaxDiskSizeBytes) {
        return; // Under limit
      }

      log.info(
        '[ThumbnailDiskCache] Over limit: $totalSize / $kMaxDiskSizeBytes bytes, evicting...',
      );

      // Sort by LRU (oldest access first), but prefer evicting higher variants
      // Strategy: evict high-rank variants first, then by LRU
      readyEntries.sort((a, b) {
        // First compare by originKey to group variants together
        final originCmp = a.originKey.compareTo(b.originKey);
        if (originCmp != 0) {
          // Different images, use LRU
          return a.lastAccessAtMs.compareTo(b.lastAccessAtMs);
        }
        // Same origin - evict higher rank first
        return b.variantRank.compareTo(a.variantRank);
      });

      var freedBytes = 0;
      final targetFree = totalSize - kMaxDiskSizeBytes;

      for (final entry in readyEntries) {
        if (freedBytes >= targetFree) {
          break;
        }

        await deleteFile(entry.key);
        freedBytes += entry.sizeBytes ?? 0;
      }

      log.info('[ThumbnailDiskCache] Evicted $freedBytes bytes');
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error evicting entries: $e');
    }
  }

  /// Clear all cache (files + ObjectBox entries)
  Future<void> clearAll() async {
    try {
      // Delete all files
      final cacheDir = Directory(_cacheDirOrThrow);
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }

      // Clear all ObjectBox entries
      _boxOrThrow.removeAll();

      log.info('[ThumbnailDiskCache] Cleared all cache');
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error clearing cache: $e');
    }
  }

  /// Get statistics for monitoring
  Future<Map<String, dynamic>> getStats() async {
    try {
      final box = _boxOrThrow;
      final total = box.count();

      final readyQuery =
          box.query(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.ready)).build();
      final readyCount = readyQuery.count();
      readyQuery.close();

      final downloadingQuery = box
          .query(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.downloading))
          .build();
      final downloadingCount = downloadingQuery.count();
      downloadingQuery.close();

      final readyEntries = box
          .query(ThumbnailCacheEntry_.status.equals(ThumbnailStatus.ready))
          .build()
          .find();
      final totalBytes = readyEntries.fold<int>(
        0,
        (sum, entry) => sum + (entry.sizeBytes ?? 0),
      );

      return {
        'total_entries': total,
        'ready': readyCount,
        'downloading': downloadingCount,
        'total_bytes': totalBytes,
        'max_bytes': kMaxDiskSizeBytes,
        'usage_percent': (totalBytes / kMaxDiskSizeBytes * 100).toStringAsFixed(1),
      };
    } catch (e) {
      log.severe('[ThumbnailDiskCache] Error getting stats: $e');
      return {};
    }
  }
}
