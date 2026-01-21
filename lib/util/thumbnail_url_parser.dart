//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/thumbnail_cache_entry.dart';

/// Parse and normalize thumbnail URLs for multi-variant support
class ThumbnailUrlParser {
  /// Parse a URL into originKey, variant, and variantRank
  static ParsedThumbnailUrl parse(String url) {
    // Check if this is a Cloudflare Image Delivery URL
    if (url.startsWith(Environment.cloudFlareImageUrlPrefix) ||
        url.startsWith('https://imagedelivery.net/')) {
      return _parseCloudflareUrl(url);
    }

    // Non-Cloudflare URL - treat as single variant
    return ParsedThumbnailUrl(
      originKey: url,
      variant: 'original',
      variantRank: 0,
      fullUrl: url,
    );
  }

  /// Parse Cloudflare Image Delivery URL
  /// Format: https://imagedelivery.net/<account>/<imageId>/<variant>
  static ParsedThumbnailUrl _parseCloudflareUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;

    if (segments.length >= 3) {
      // Last segment is the variant
      final variant = segments.last;
      
      // Origin key is URL without the last segment
      final originSegments = segments.sublist(0, segments.length - 1);
      final originKey = Uri(
        scheme: uri.scheme,
        host: uri.host,
        pathSegments: originSegments,
      ).toString();

      return ParsedThumbnailUrl(
        originKey: originKey,
        variant: variant,
        variantRank: VariantRank.getRank(variant),
        fullUrl: url,
      );
    }

    // Malformed Cloudflare URL - treat as single variant
    return ParsedThumbnailUrl(
      originKey: url,
      variant: 'original',
      variantRank: 0,
      fullUrl: url,
    );
  }

  /// Build Cloudflare URL from originKey + variant
  static String buildCloudflareUrl(String originKey, String variant) {
    // If originKey already ends with a variant-like segment, replace it
    final uri = Uri.parse(originKey);
    final segments = List<String>.from(uri.pathSegments);
    
    // Add variant segment
    segments.add(variant);
    
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      pathSegments: segments,
    ).toString();
  }

  /// Generate cache key from parsed URL
  static String generateKey(ParsedThumbnailUrl parsed) {
    return '${parsed.originKey}|${parsed.variant}';
  }

  /// Map widget size to appropriate Cloudflare variant
  /// This helps select the right variant based on display dimensions
  static String selectVariantForSize({
    required int widthPx,
    required int heightPx,
  }) {
    final maxDim = widthPx > heightPx ? widthPx : heightPx;

    // Map to Cloudflare variants based on max dimension
    if (maxDim <= 200) {
      return 'xs'; // Extra small
    } else if (maxDim <= 400) {
      return 's'; // Small
    } else if (maxDim <= 800) {
      return 'm'; // Medium
    } else if (maxDim <= 1200) {
      return 'l'; // Large
    } else {
      return 'xl'; // Extra large
    }
  }
}

/// Parsed thumbnail URL components
class ParsedThumbnailUrl {
  const ParsedThumbnailUrl({
    required this.originKey,
    required this.variant,
    required this.variantRank,
    required this.fullUrl,
  });

  /// Base URL without variant (for grouping multi-variant images)
  final String originKey;

  /// Variant name (xs, s, m, l, xl, original)
  final String variant;

  /// Numeric rank for comparison
  final int variantRank;

  /// Full URL with variant segment
  final String fullUrl;

  @override
  String toString() =>
      'ParsedThumbnailUrl(originKey: $originKey, variant: $variant, '
      'rank: $variantRank)';
}
