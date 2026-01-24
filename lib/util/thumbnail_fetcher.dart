//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/model/thumbnail_cache_entry.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/thumbnail_disk_cache.dart';
import 'package:autonomy_flutter/util/vips_isolate_pool.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';

/// Cancelable thumbnail fetch handle
class ThumbnailFetchHandle {
  ThumbnailFetchHandle(this._cancelCompleter);

  final Completer<void> _cancelCompleter;
  bool _canceled = false;

  bool get isCanceled => _canceled;

  void cancel() {
    if (!_canceled) {
      _canceled = true;
      if (!_cancelCompleter.isCompleted) {
        _cancelCompleter.complete();
      }
    }
  }
}

/// Result of a thumbnail fetch operation
class ThumbnailFetchResult {
  const ThumbnailFetchResult({
    required this.success,
    this.bytes,
    this.error,
    this.etag,
    this.lastModified,
  });

  final bool success;
  final Uint8List? bytes;
  final String? error;
  final String? etag;
  final String? lastModified;
}

/// Foreground thumbnail fetcher using Dart HttpClient with libvips resizing
class DartHttpThumbnailFetcher {
  factory DartHttpThumbnailFetcher() => _instance;

  DartHttpThumbnailFetcher._() {
    _httpClient.maxConnectionsPerHost = kMaxConnectionsPerHost;
    _httpClient.connectionTimeout = const Duration(seconds: 30);
    _httpClient.idleTimeout = const Duration(seconds: 60);

    // Initialize vips isolate pool for parallel resizing
    _vipsPool.initialize().then((_) {
      log.info(
        '[DartHttpFetcher] Vips isolate pool initialized: '
        '${_vipsPool.getStatus()}',
      );
    }).catchError((Object e) {
      log.severe('[DartHttpFetcher] Failed to initialize vips pool: $e');
    });

    log.info(
      '[DartHttpFetcher] Initialized: maxConnections=$kMaxConnectionsPerHost, '
      'timeout=${kRequestTimeout.inSeconds}s',
    );
  }

  static final DartHttpThumbnailFetcher _instance =
      DartHttpThumbnailFetcher._();

  final HttpClient _httpClient = HttpClient();
  // Pool size matches max in-flight downloads from prefetch service
  final VipsIsolatePool _vipsPool = VipsIsolatePool(poolSize: 8);
  Directory? _tempDir;
  static const int kMaxConnectionsPerHost =
      8; // Parallel HTTP connections per host
  static const Duration kRequestTimeout =
      Duration(seconds: 60); // Increased for debugging

  /// Fetch thumbnail with cancellation support
  /// Flow: download -> file (keep as original, no resize)
  /// Returns bytes loaded from file
  Future<ThumbnailFetchResult> fetch({
    required String url,
    required ThumbnailFetchHandle handle,
    bool saveAsOriginal = false,
  }) async {
    HttpClientRequest? request;
    HttpClientResponse? response;
    File? tempFile;
    IOSink? sink;

    try {
      final uri = Uri.parse(url);
      final startTime = DateTime.now();

      // Create request
      request = await _httpClient.getUrl(uri).timeout(
        kRequestTimeout,
        onTimeout: () {
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          log.warning(
            '[DartHttpFetcher] Request creation timeout after ${elapsed}s '
            'for $url',
          );
          throw TimeoutException('Request timeout for $url');
        },
      );

      // Get response
      response = await request.close().timeout(
        kRequestTimeout,
        onTimeout: () {
          throw TimeoutException('Response timeout for $url');
        },
      );

      if (response.statusCode != 200) {
        // Drain the response to close the connection
        await response.drain<void>();
        return ThumbnailFetchResult(
          success: false,
          error: 'HTTP ${response.statusCode}',
        );
      }

      // Extract cache headers
      final etag = response.headers.value('etag');
      final lastModified = response.headers.value('last-modified');

      // Ensure temp directory exists
      _tempDir ??= await getTemporaryDirectory();

      // Hash URL to create deterministic filename
      final urlHash = md5.convert(utf8.encode(url)).toString();

      // Download directly to temp file
      tempFile = File('${_tempDir!.path}/$urlHash.tmp');
      sink = tempFile.openWrite();

      try {
        await response.pipe(sink);
      } catch (e) {
        log.warning('[DartHttpFetcher] Error piping response to file: $e');
        rethrow;
      }

      // Load file to memory for return (no resize here)
      final finalBytes = await tempFile.readAsBytes();

      // Cleanup temp file
      try {
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (e) {
        log.warning('[DartHttpFetcher] Error cleaning up temp file: $e');
      }

      return ThumbnailFetchResult(
        success: true,
        bytes: finalBytes,
        etag: etag,
        lastModified: lastModified,
      );
    } catch (e, stackTrace) {
      log.severe('[DartHttpFetcher] Error fetching $url: $e');

      // Ensure sink is closed
      if (sink != null) {
        try {
          await sink.close();
        } catch (closeError) {
          log.warning('[DartHttpFetcher] Error closing sink: $closeError');
        }
      }

      // Drain response to close connection
      if (response != null) {
        try {
          await response.drain<void>();
        } catch (drainError) {
          log.warning('[DartHttpFetcher] Error draining response: $drainError');
        }
      }

      // Cleanup temp file on error
      try {
        if (tempFile != null && tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (cleanupError) {
        log.warning(
          '[DartHttpFetcher] Error cleaning up after failure: $cleanupError',
        );
      }

      // Don't report cancellation errors
      if (!e.toString().contains('HttpException') || !handle.isCanceled) {
        unawaited(
          Sentry.captureException(
            'Thumbnail fetch error for $url: $e',
            stackTrace: stackTrace,
          ),
        );
      }

      return ThumbnailFetchResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Close the HTTP client and vips pool (cleanup)
  Future<void> dispose() async {
    _httpClient.close();
    await _vipsPool.dispose();
    log.info('[DartHttpFetcher] HTTP client and vips pool closed');
  }
}

/// High-level thumbnail fetcher that coordinates cache + network
class ThumbnailFetcher {
  ThumbnailFetcher({
    required this.diskCache,
    required this.httpFetcher,
    VipsIsolatePool? vipsPool,
  }) : _vipsPool = vipsPool ?? _sharedVipsPool;

  final ThumbnailDiskCache diskCache;
  final DartHttpThumbnailFetcher httpFetcher;
  final VipsIsolatePool _vipsPool;

  // Shared pool across all fetcher instances
  static final VipsIsolatePool _sharedVipsPool = VipsIsolatePool(poolSize: 8);

  /// Fetch thumbnail with smart multi-size caching
  /// Strategy:
  /// 1. Check for exact size match
  /// 2. Check for similar size (within 20% margin)
  /// 3. Check if original exists → resize from original
  /// 4. Download original → save → resize if needed
  ///
  /// IMPORTANT: Only targetWidth should be provided to maintain aspect ratio.
  /// If targetHeight is 0 or null, libvips will calculate it automatically.
  Future<ThumbnailFetchResult> fetchThumbnail({
    required String url,
    required ThumbnailFetchHandle handle,
    int? targetWidth,
    int? targetHeight,
  }) async {
    try {
      await _vipsPool.initialize();

      // Skip resizing for Cloudflare imagedelivery.net URLs
      // They already provide pre-sized variants, so resizing is inefficient
      final isCloudflareUrl = url.contains('imagedelivery.net');

      // Normalize height: 0 means auto-calculate (maintain aspect ratio)
      final effectiveHeight =
          (targetHeight == null || targetHeight == 0) ? null : targetHeight;

      // Determine if resize is needed
      // Don't resize Cloudflare URLs - rely on their variant system instead
      // Only need targetWidth to maintain aspect ratio (height will be calculated)
      final needsResize = !isCloudflareUrl && targetWidth != null;

      if (isCloudflareUrl && targetWidth != null) {
        log.info(
          '[ThumbnailFetcher] Skipping resize for Cloudflare URL, '
          'using variant system instead: width=$targetWidth',
        );
      }

      if (needsResize) {
        // Strategy 1: Check for exact size match (only if height was specified)
        if (effectiveHeight != null) {
          final exactMatch =
              diskCache.getExactSize(url, targetWidth, effectiveHeight);
          if (exactMatch != null) {
            final file = diskCache.readFile(exactMatch.key);
            if (file != null) {
              final bytes = await file.readAsBytes();
              return ThumbnailFetchResult(success: true, bytes: bytes);
            }
          }
        }

        // Strategy 2: Check if original exists → resize from it
        final original = diskCache.getOriginal(url);
        if (original != null) {
          final originalFile = diskCache.readFile(original.key);
          if (originalFile != null) {
            return await _resizeFromOriginal(
              url: url,
              originalPath: originalFile.path,
              targetWidth: targetWidth,
              targetHeight: effectiveHeight,
              handle: handle,
            );
          }
        }
      } else {
        // No resize needed, check for original
        final original = diskCache.getOriginal(url);
        if (original != null) {
          final file = diskCache.readFile(original.key);
          if (file != null) {
            final bytes = await file.readAsBytes();
            return ThumbnailFetchResult(success: true, bytes: bytes);
          }
        }
      }

      // Strategy 3: Download original and optionally resize

      final downloadResult = await httpFetcher.fetch(
        url: url,
        handle: handle,
        saveAsOriginal: true,
      );

      log.info(
        '[ThumbnailFetcher] Download completed, success: ${downloadResult.success}',
      );

      if (!downloadResult.success || downloadResult.bytes == null) {
        return downloadResult;
      }

      // Save original to cache
      final originalKey = ThumbnailCacheKey.original(url);
      await diskCache.writeTempThenCommit(
        originalKey,
        downloadResult.bytes!,
        etag: downloadResult.etag,
        lastModified: downloadResult.lastModified,
        isOriginal: true,
      );

      // If resize is needed, create resized version
      if (needsResize) {
        final originalEntry = diskCache.getByKey(originalKey);
        if (originalEntry != null && originalEntry.localPath != null) {
          final originalFile = File(
            diskCache.getFullPath(originalEntry.localPath!),
          );

          return await _resizeFromOriginal(
            url: url,
            originalPath: originalFile.path,
            targetWidth: targetWidth,
            targetHeight: effectiveHeight,
            handle: handle,
          );
        }
      }

      // No resize needed, return original
      return downloadResult;
    } catch (e, stackTrace) {
      log.severe('[ThumbnailFetcher] Error in fetchThumbnail: $e');
      unawaited(
        Sentry.captureException(
          'ThumbnailFetcher error: $e',
          stackTrace: stackTrace,
        ),
      );
      return ThumbnailFetchResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Resize from original file and save to cache
  /// If targetHeight is null, aspect ratio will be maintained based on targetWidth
  Future<ThumbnailFetchResult> _resizeFromOriginal({
    required String url,
    required String originalPath,
    required int targetWidth,
    int? targetHeight,
    required ThumbnailFetchHandle handle,
  }) async {
    File? resizedFile;

    try {
      // Create temp file for resized output
      final tempDir = await getTemporaryDirectory();
      final urlHash = md5.convert(utf8.encode(url)).toString();
      final heightSuffix = targetHeight != null ? 'x$targetHeight' : '';
      resizedFile =
          File('${tempDir.path}/${urlHash}_${targetWidth}$heightSuffix.tmp');

      // Resize using libvips (aspect ratio maintained if height is null)
      final success = await _vipsPool.resizeFile(
        inputPath: originalPath,
        outputPath: resizedFile.path,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );

      if (!success || !await resizedFile.exists()) {
        log.warning(
          '[ThumbnailFetcher] Resize from original failed, '
          'loading original instead',
        );
        final originalBytes = await File(originalPath).readAsBytes();
        return ThumbnailFetchResult(success: true, bytes: originalBytes);
      }

      // Read resized bytes
      final resizedBytes = await resizedFile.readAsBytes();

      // Save to cache with size metadata
      // For aspect-ratio maintained images, use 0 for height
      final resizedKey = ThumbnailCacheKey.resized(
        url,
        targetWidth,
        targetHeight ?? 0,
      );
      await diskCache.writeTempThenCommit(
        resizedKey,
        resizedBytes,
        isOriginal: false,
        imageWidth: targetWidth,
        imageHeight: targetHeight ?? 0,
      );

      // Cleanup temp file
      try {
        if (await resizedFile.exists()) {
          await resizedFile.delete();
        }
      } catch (e) {
        log.warning('[ThumbnailFetcher] Error cleaning up temp file: $e');
      }

      log.info(
        '[ThumbnailFetcher] Created and cached resized version: '
        'width=$targetWidth${targetHeight != null ? ", height=$targetHeight" : " (aspect ratio maintained)"}',
      );

      return ThumbnailFetchResult(success: true, bytes: resizedBytes);
    } catch (e, stackTrace) {
      log.severe('[ThumbnailFetcher] Error resizing from original: $e');

      // Cleanup on error
      try {
        if (resizedFile != null && await resizedFile.exists()) {
          await resizedFile.delete();
        }
      } catch (cleanupError) {
        log.warning('[ThumbnailFetcher] Error cleaning up: $cleanupError');
      }

      unawaited(
        Sentry.captureException(
          'Resize from original error: $e',
          stackTrace: stackTrace,
        ),
      );

      // Fallback to original
      try {
        final originalBytes = await File(originalPath).readAsBytes();
        return ThumbnailFetchResult(success: true, bytes: originalBytes);
      } catch (fallbackError) {
        return ThumbnailFetchResult(
          success: false,
          error: e.toString(),
        );
      }
    }
  }

  /// Dispose resources (no-op for shared pool)
  Future<void> dispose() async {
    // Pool is shared, don't dispose it here
  }

  /// Dispose shared vips pool (call on app shutdown)
  static Future<void> disposeSharedPool() async {
    await _sharedVipsPool.dispose();
  }
}
