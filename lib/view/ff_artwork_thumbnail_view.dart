import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/thumbnail_cache_entry.dart';
import 'package:autonomy_flutter/service/thumbnail_prefetch_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/svg_utils.dart';
import 'package:autonomy_flutter/util/thumbnail_disk_cache.dart';
import 'package:autonomy_flutter/util/thumbnail_url_parser.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class FFArtworkThumbnailView extends StatefulWidget {
  const FFArtworkThumbnailView({
    required this.url,
    this.cacheWidth,
    this.cacheHeight,
    super.key,
    this.onTap,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.cacheScale = 3.0,
  });

  final String url;
  final Function? onTap;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double cacheScale;

  @override
  State<FFArtworkThumbnailView> createState() => _FFArtworkThumbnailViewState();
}

class _FFArtworkThumbnailViewState extends State<FFArtworkThumbnailView> {
  bool _hasSvgError = false;
  StreamSubscription<ThumbnailUpdate>? _updateSubscription;
  ThumbnailCacheEntry? _currentEntry;
  String? _currentOriginKey;
  bool _didInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _setupUpdateListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      _loadThumbnail();
    }
  }

  @override
  void didUpdateWidget(FFArtworkThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.cacheWidth != widget.cacheWidth ||
        oldWidget.cacheHeight != widget.cacheHeight) {
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    super.dispose();
  }

  void _setupUpdateListener() {
    try {
      final prefetchService = injector<ThumbnailPrefetchService>();
      _updateSubscription = prefetchService.updates.listen((update) {
        if (mounted && update.originKey == _currentOriginKey) {
          // Thumbnail updated for our origin - reload
          setState(() {
            _loadThumbnail();
          });
        }
      });
    } catch (e) {
      log.info('[FFArtworkThumbnailView] Error setting up listener: $e');
    }
  }

  void _loadThumbnail() {
    try {
      final parsed = ThumbnailUrlParser.parse(widget.url);
      _currentOriginKey = parsed.originKey;

      // Compute target width from widget constraints and device pixel ratio
      // IMPORTANT: Only use width to maintain aspect ratio automatically
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
      final targetWidthPx =
          widget.cacheWidth != null ? (widget.cacheWidth! * dpr).toInt() : null;

      // Only select variants for Cloudflare URLs
      final isCloudflareUrl = widget.url.contains('imagedelivery.net');
      final selectedVariant = isCloudflareUrl && targetWidthPx != null
          ? ThumbnailUrlParser.selectVariantForSize(
              widthPx: targetWidthPx,
              heightPx: targetWidthPx, // Use same value for variant selection
            )
          : parsed.variant;

      final selectedRank = VariantRank.getRank(selectedVariant);

      // Try to get best available variant from cache
      final diskCache = injector<ThumbnailDiskCache>();
      final bestAvailable = diskCache.getBestAvailableVariant(
        parsed.originKey,
        selectedRank,
      );

      _currentEntry = bestAvailable;

      // If we don't have the requested variant, trigger prefetch
      if (bestAvailable == null || bestAvailable.variantRank < selectedRank) {
        final requestedUrl =
            selectedVariant == parsed.variant || !isCloudflareUrl
                ? widget.url
                : ThumbnailUrlParser.buildCloudflareUrl(
                    parsed.originKey,
                    selectedVariant,
                  );

        final prefetchService = injector<ThumbnailPrefetchService>();
        prefetchService.prefetchUrls(
          urls: [requestedUrl],
          // Only pass width - libvips will maintain aspect ratio
          targetSize: targetWidthPx != null
              ? ThumbnailSize(widthPx: targetWidthPx, heightPx: 0)
              : null,
          priority: PrefetchPriority.visible,
        );
      }
    } catch (e) {
      log.severe('[FFArtworkThumbnailView] Error loading thumbnail: $e');
    }
  }

  /// Check if the URL is a data URI (e.g., data:image/svg+xml;base64,...)
  bool _isDataUri(String url) {
    return url.startsWith('data:image');
  }

  /// Check if the data URI is an SVG
  bool _isSvgDataUri(String dataUri) {
    return dataUri.startsWith('data:image/svg+xml');
  }

  /// Extract base64 data from data URI
  Uint8List? _decodeDataUri(String dataUri) {
    try {
      // Find the comma that separates the header from the data
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }

      // Extract the base64 part after the comma
      var base64Data = dataUri.substring(commaIndex + 1);

      // Try URL decoding in case the base64 is URL-encoded
      try {
        base64Data = Uri.decodeComponent(base64Data);
      } catch (e) {
        // If URL decoding fails, use the original string
      }

      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  /// Extract SVG string from data URI
  /// Handles both base64-encoded and URL-encoded SVG data URIs
  String? _decodeSvgDataUri(String dataUri) {
    // Use SvgUtils to decode and convert SVG data URI
    return SvgUtils.decodeAndConvertSvgDataUri(dataUri);
  }

  Widget _buildImageWidget() {
    // Handle data URI images (keep existing logic)
    if (_isDataUri(widget.url)) {
      final imageBytes = _decodeDataUri(widget.url);
      if (imageBytes != null) {
        // Handle SVG data URI
        if (_isSvgDataUri(widget.url)) {
          if (_hasSvgError) {
            return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
          }

          // Try using SvgPicture.string first (more reliable for SVG)
          final svgString = _decodeSvgDataUri(widget.url);
          if (svgString != null) {
            // Use a separate widget to handle SVG rendering with better error handling
            return _SvgPictureWidget(
              svgString: svgString,
              imageBytes: imageBytes,
              cacheWidth: widget.cacheWidth?.toDouble(),
              cacheHeight: widget.cacheHeight?.toDouble(),
              placeholder: widget.placeholder,
              errorWidget: widget.errorWidget,
              fit: widget.fit,
              onError: () {
                if (mounted) {
                  setState(() {
                    _hasSvgError = true;
                  });
                }
              },
            );
          } else {
            // If string decoding fails, try memory approach with original bytes
            try {
              return SvgPicture.memory(
                imageBytes,
                width: widget.cacheWidth?.toDouble(),
                height: widget.cacheHeight?.toDouble(),
                fit: widget.fit,
                placeholderBuilder: (context) =>
                    widget.placeholder ?? const GalleryThumbnailPlaceholder(),
              );
            } catch (e) {
              // If SVG parsing fails, show error widget
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _hasSvgError = true;
                  });
                }
              });
              return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
            }
          }
        }
        // Handle other image data URIs
        return Image.memory(
          imageBytes,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) =>
              widget.errorWidget ?? const GalleryThumbnailErrorWidget(),
        );
      } else {
        // If decoding fails, show error widget
        return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
      }
    }

    // Handle network SVG images
    if (widget.url.isSvgImage()) {
      return SvgPicture.network(
        widget.url,
        width: widget.cacheWidth?.toDouble(),
        height: widget.cacheHeight?.toDouble(),
        fit: widget.fit,
        placeholderBuilder: (context) =>
            widget.placeholder ?? const GalleryThumbnailPlaceholder(),
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ?? const GalleryThumbnailErrorWidget(),
      );
    }

    // Handle regular network images with new cache system
    return _buildCachedNetworkImage();
  }

  /// Build cached network image using new pipeline
  Widget _buildCachedNetworkImage() {
    // If we have a cached entry, display it
    if (_currentEntry != null && _currentEntry!.localPath != null) {
      try {
        final diskCache = injector<ThumbnailDiskCache>();
        final file = diskCache.readFile(_currentEntry!.key);
        if (file != null) {
          // When both are specified, Flutter decodes the image to EXACTLY those dimensions,
          // which STRETCHES the image if the aspect ratio doesn't match.
          //
          // Our flow:
          // 1. libvips resizes images maintaining aspect ratio
          // 2. Cached files are already properly sized
          // 3. Let BoxFit.contain handle display scaling
          // 4. Parent SizedBox provides layout constraints
          //
          // This ensures images always maintain their correct aspect ratio.
          return Image.file(
            file,
            fit: widget.fit,
            gaplessPlayback:
                true, // Smooth upgrade from lower to higher variant
            errorBuilder: (context, error, stackTrace) =>
                widget.errorWidget ?? const GalleryThumbnailErrorWidget(),
          );
        }
      } catch (e) {
        log.info('[FFArtworkThumbnailView] Error reading cached file: $e');
      }
    }

    // No cache or cache read failed - show placeholder
    // The prefetch service is already warming this image in the background
    return widget.placeholder ?? const GalleryThumbnailPlaceholder();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => widget.onTap?.call(),
        child: LayoutBuilder(builder: (context, constraints) {
          return ClipRect(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: _buildImageWidget(),
            ),
          );
        }),
      );
}

/// Widget to handle SVG rendering with error handling
class _SvgPictureWidget extends StatefulWidget {
  const _SvgPictureWidget({
    required this.svgString,
    required this.imageBytes,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.errorWidget,
    this.onError,
    this.fit = BoxFit.contain,
  });

  final String svgString;
  final Uint8List imageBytes;
  final double? cacheWidth;
  final double? cacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BoxFit fit;
  final VoidCallback? onError;

  @override
  State<_SvgPictureWidget> createState() => _SvgPictureWidgetState();
}

class _SvgPictureWidgetState extends State<_SvgPictureWidget> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
    }

    // Try SvgPicture.string first
    try {
      return SvgPicture.string(
        widget.svgString,
        width: widget.cacheWidth,
        height: widget.cacheHeight,
        fit: widget.fit,
        allowDrawingOutsideViewBox: true,
        placeholderBuilder: (context) =>
            widget.placeholder ?? const GalleryThumbnailPlaceholder(),
      );
    } catch (e) {
      // If string parsing fails, try memory approach
      try {
        final convertedBytes = utf8.encode(widget.svgString);
        return SvgPicture.memory(
          Uint8List.fromList(convertedBytes),
          width: widget.cacheWidth,
          height: widget.cacheHeight,
          fit: widget.fit,
          allowDrawingOutsideViewBox: true,
          placeholderBuilder: (context) =>
              widget.placeholder ?? const GalleryThumbnailPlaceholder(),
        );
      } catch (e2) {
        // If both fail, notify parent and show error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hasError = true;
            });
            widget.onError?.call();
          }
        });
        return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
      }
    }
  }
}
