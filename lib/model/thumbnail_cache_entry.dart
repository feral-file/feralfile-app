//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:objectbox/objectbox.dart';

/// Thumbnail cache state for multi-variant images
/// Manages lifecycle: missing → downloading → ready/failed
@Entity()
class ThumbnailCacheEntry {
  /// ObjectBox internal ID
  int id;

  /// Unique key: originKey|variant (e.g. "https://.../<imageId>|xs")
  @Unique()
  String key;

  /// Base URL without variant segment (for Cloudflare multi-variant grouping)
  @Index()
  String originKey;

  /// Variant name: xs, s, m, l, xl, or 'original' for non-Cloudflare
  @Index()
  String variant;

  /// Variant rank for ordering (xs=0, s=1, m=2, l=3, xl=4, original=0)
  /// Allows quick "best available <= requested" queries
  @Index()
  int variantRank;

  /// Full URL for this variant (includes variant segment for Cloudflare)
  @Index()
  String url;

  /// Current status: 0=missing, 1=downloading, 2=ready, 3=failed, 4=evicted
  @Index()
  int status;

  /// Local file path (absolute or relative to cache dir)
  String? localPath;

  /// File size in bytes
  int? sizeBytes;

  /// Actual image width (for resized images, 0 for original)
  int? imageWidth;

  /// Actual image height (for resized images, 0 for original)
  int? imageHeight;

  /// Whether this is the original downloaded file (not resized)
  @Index()
  bool isOriginal;

  /// Creation timestamp (milliseconds since epoch)
  int createdAtMs;

  /// Last access timestamp for LRU eviction
  @Index()
  int lastAccessAtMs;

  /// Expiration timestamp for TTL (milliseconds since epoch)
  int? expiresAtMs;

  /// HTTP ETag for conditional requests
  String? etag;

  /// HTTP Last-Modified for conditional requests
  String? lastModified;

  /// Last error timestamp
  int? lastErrorAtMs;

  /// Consecutive error count for backoff
  int errorCount;

  /// Last error message
  String? lastError;

  /// In-flight backend type: 0=none, 1=dartHttp, 2=iosUrlSession, 3=androidDownloadManager
  int? inFlightBackend;

  /// In-flight task ID (for cancellation)
  String? inFlightTaskId;

  ThumbnailCacheEntry({
    this.id = 0,
    required this.key,
    required this.originKey,
    required this.variant,
    required this.variantRank,
    required this.url,
    required this.status,
    this.localPath,
    this.sizeBytes,
    this.imageWidth,
    this.imageHeight,
    this.isOriginal = false,
    required this.createdAtMs,
    required this.lastAccessAtMs,
    this.expiresAtMs,
    this.etag,
    this.lastModified,
    this.lastErrorAtMs,
    this.errorCount = 0,
    this.lastError,
    this.inFlightBackend,
    this.inFlightTaskId,
  });
}

/// Helper to generate cache key for specific size
class ThumbnailCacheKey {
  /// Check if URL is from Cloudflare Image Delivery (uses variant system)
  static bool _isCloudflareUrl(String url) {
    // Only imagedelivery.net uses the variant system
    return url.contains('imagedelivery.net');
  }

  /// Generate key for original image
  /// Returns URL as-is for all direct downloads
  static String original(String url) {
    // For cache keys, always use URL as-is for original files
    return url;
  }

  /// Generate key for resized image with specific dimensions
  static String resized(String url, int width, int height) {
    return '$url|${width}x$height';
  }

  /// Parse key to extract URL and size info
  static Map<String, dynamic> parse(String key) {
    final parts = key.split('|');
    if (parts.length != 2) {
      // No suffix means direct URL (original)
      return {'url': key, 'isOriginal': true, 'width': 0, 'height': 0};
    }

    final url = parts[0];
    final sizeInfo = parts[1];

    if (sizeInfo == 'original') {
      return {'url': url, 'isOriginal': true, 'width': 0, 'height': 0};
    }

    final dimensions = sizeInfo.split('x');
    if (dimensions.length == 2) {
      return {
        'url': url,
        'isOriginal': false,
        'width': int.tryParse(dimensions[0]) ?? 0,
        'height': int.tryParse(dimensions[1]) ?? 0,
      };
    }

    return {'url': key, 'isOriginal': true, 'width': 0, 'height': 0};
  }
}

/// Status enum values (stored as int in ObjectBox)
class ThumbnailStatus {
  static const int missing = 0;
  static const int downloading = 1;
  static const int ready = 2;
  static const int failed = 3;
  static const int evicted = 4;
}

/// Backend type enum values (stored as int in ObjectBox)
class ThumbnailBackend {
  static const int none = 0;
  static const int dartHttp = 1;
  static const int iosUrlSession = 2;
  static const int androidDownloadManager = 3;
}

/// Variant rank mapping for Cloudflare image delivery
class VariantRank {
  static const Map<String, int> ranks = {
    'xs': 0,
    's': 1,
    'm': 2,
    'l': 3,
    'xl': 4,
    'original': 0,
  };

  static int getRank(String variant) => ranks[variant] ?? 0;
}
