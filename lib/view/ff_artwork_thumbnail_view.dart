import 'dart:convert';
import 'dart:typed_data';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/svg_utils.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/feralfile_cache_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
    // Handle data URI images
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
          width: widget.cacheWidth?.toDouble(),
          height: widget.cacheHeight?.toDouble(),
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) =>
              widget.errorWidget ?? const GalleryThumbnailErrorWidget(),
        );
      } else {
        // If decoding fails, show error widget
        return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
      }
    }

    // Handle regular network images
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

    return FFCacheNetworkImage(
      cacheManager: injector<CacheManager>(),
      imageUrl: widget.url,
      memCacheWidth: widget.cacheWidth,
      memCacheHeight: widget.cacheHeight,
      maxWidthDiskCache: widget.cacheWidth,
      maxHeightDiskCache: widget.cacheHeight,
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.placeholder ?? const GalleryThumbnailPlaceholder(),
      errorWidget: (context, url, error) {
        // For PathNotFoundException, show placeholder instead of error
        // This happens during concurrent cache operations and usually resolves on retry
        final errorString = error.toString();
        if (errorString.contains('PathNotFoundException') ||
            errorString.contains('Cannot open file')) {
          return widget.placeholder ?? const GalleryThumbnailPlaceholder();
        }
        return widget.errorWidget ?? const GalleryThumbnailErrorWidget();
      },
      cacheScale: widget.cacheScale,
    );
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
