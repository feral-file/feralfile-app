import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/nft_rendering/svg_image.dart';
import 'package:flutter/material.dart';

class SVGNFTRenderingWidget extends NFTRenderingWidget {
  final String previewURL;
  final Widget? noPreviewUrlWidget;
  final Widget? loadingWidget;
  final VoidCallback? onLoaded;
  final VoidCallback? onError;

  const SVGNFTRenderingWidget({
    required this.previewURL,
    super.key,
    this.noPreviewUrlWidget,
    this.loadingWidget,
    this.onLoaded,
    this.onError,
  });

  @override
  State<SVGNFTRenderingWidget> createState() => _SVGNFTRenderingWidgetState();
}

class _SVGNFTRenderingWidgetState extends State<SVGNFTRenderingWidget> {
  @override
  void initState() {
    super.initState();
  }

  Widget _buildSvgWidget() {
    if (widget.previewURL.isEmpty) {
      return widget.noPreviewUrlWidget ?? const SizedBox.shrink();
    }

    return SvgImage(
      url: widget.previewURL,
      fallbackToWebView: true,
      loadingWidgetBuilder: (context) =>
          widget.loadingWidget ?? const LoadingWidget(),
      onLoaded: () {
        widget.onLoaded?.call();
      },
      onError: () {
        widget.onError?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) => _buildSvgWidget();
}
