import 'dart:convert';
import 'dart:typed_data';

import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/util/svg_utils.dart';
import 'package:flutter/material.dart';

class ImageNFTRenderingWidget extends NFTRenderingWidget {
  final String previewURL;
  final VoidCallback? onLoaded;
  final Widget? noPreviewUrlWidget;
  final Widget? errorWidget;
  final ImageLoadingBuilder? loadingBuilder;

  const ImageNFTRenderingWidget({
    required this.previewURL,
    super.key,
    this.onLoaded,
    this.noPreviewUrlWidget,
    this.errorWidget,
    this.loadingBuilder,
  });

  @override
  State<ImageNFTRenderingWidget> createState() =>
      _ImageNFTRenderingWidgetState();
}

class _ImageNFTRenderingWidgetState extends State<ImageNFTRenderingWidget> {
  @override
  void initState() {
    super.initState();
    // Notify when the widget has loaded
    widget.onLoaded?.call();
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

  Widget _buildImageWidget() {
    // If the preview URL is not provided, show a fallback widget
    if (widget.previewURL.isEmpty) {
      return widget.noPreviewUrlWidget ?? const SizedBox.shrink();
    }

    // Handle data URI images
    if (_isDataUri(widget.previewURL)) {
      // Handle SVG data URI - convert and re-encode
      if (_isSvgDataUri(widget.previewURL)) {
        final svgString =
            SvgUtils.decodeAndConvertSvgDataUri(widget.previewURL);
        if (svgString != null) {
          // Re-encode the converted SVG string to bytes
          final convertedBytes = utf8.encode(svgString);
          final imageBytes = Uint8List.fromList(convertedBytes);

          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(
              context,
              Image.memory(
                imageBytes,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: widget.errorWidget ?? const Icon(Icons.error),
                ),
                fit: BoxFit.cover,
              ),
              null, // loadingProgress is null for memory images
            );
          }
          return Image.memory(
            imageBytes,
            errorBuilder: (context, error, stackTrace) => Center(
              child: widget.errorWidget ?? const Icon(Icons.error),
            ),
            fit: BoxFit.cover,
          );
        } else {
          // If SVG decoding/conversion fails, show error widget
          return Center(
            child: widget.errorWidget ?? const Icon(Icons.error),
          );
        }
      }

      // Handle other image data URIs (non-SVG)
      final imageBytes = _decodeDataUri(widget.previewURL);
      if (imageBytes != null) {
        // Image.memory loads synchronously, so we can show loading state if needed
        if (widget.loadingBuilder != null) {
          return widget.loadingBuilder!(
            context,
            Image.memory(
              imageBytes,
              errorBuilder: (context, error, stackTrace) => Center(
                child: widget.errorWidget ?? const Icon(Icons.error),
              ),
              fit: BoxFit.cover,
            ),
            null, // loadingProgress is null for memory images
          );
        }
        return Image.memory(
          imageBytes,
          errorBuilder: (context, error, stackTrace) => Center(
            child: widget.errorWidget ?? const Icon(Icons.error),
          ),
          fit: BoxFit.cover,
        );
      } else {
        // If decoding fails, show error widget
        return Center(
          child: widget.errorWidget ?? const Icon(Icons.error),
        );
      }
    }

    // Handle regular network images
    return Image.network(
      widget.previewURL,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: (context, url, error) => Center(
        child: widget.errorWidget ?? const Icon(Icons.error),
      ),
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) => _buildImageWidget();
}
