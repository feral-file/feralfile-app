import 'dart:convert';

import 'package:autonomy_flutter/nft_rendering/feralfile_webview.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/material.dart';

class SvgImage extends StatefulWidget {
  final String url;
  final bool fallbackToWebView;
  final WidgetBuilder? loadingWidgetBuilder;
  final WidgetBuilder? errorWidgetBuilder;
  final WidgetBuilder? unsupportWidgetBuilder;
  final VoidCallback? onLoaded;
  final VoidCallback? onError;

  const SvgImage({
    required this.url,
    super.key,
    this.fallbackToWebView = false,
    this.loadingWidgetBuilder,
    this.errorWidgetBuilder,
    this.onLoaded,
    this.onError,
    this.unsupportWidgetBuilder,
  });

  String getHtml(String svgImageURL) {
    // Escape HTML entities to prevent XSS/injection attacks
    final escapedUrl = svgImageURL
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final html = '''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'self' https: data:; script-src 'none'; object-src 'none';">
        <style>
          html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
          }
          img{
            width: 100%;
            height: 100%;
            object-fit: contain;
          }
        </style>
      </head>
      <body>
        <div></div>
        <img src="$escapedUrl" alt="SVG Image" />
      </body>
    </html>
    ''';

    return html;
  }

  @override
  State<StatefulWidget> createState() => _SvgImageState();
}

class _SvgImageState extends State<SvgImage> {
  bool _webviewLoadFailed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(SvgImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset error state when URL changes
    if (oldWidget.url != widget.url) {
      setState(() {
        _webviewLoadFailed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validate URL
    if (widget.url.isEmpty) {
      return widget.errorWidgetBuilder?.call(context) ?? const SizedBox();
    }

    if (_webviewLoadFailed) {
      return widget.unsupportWidgetBuilder?.call(context) ?? const SizedBox();
    }

    return FeralFileWebview(
      key: Key(widget.url),
      uri: Uri.dataFromString(
        widget.getHtml(widget.url),
        mimeType: 'text/html',
        encoding: utf8, // Use utf8 constant instead of getByName
      ),
      onLoaded: (controller) {
        widget.onLoaded?.call();
      },
      onResourceError: (controller, error) {
        log.info('SVG WebView resource error: ${error.description}');
        setState(() {
          _webviewLoadFailed = true;
        });
        widget.onError?.call();
      },
      onHttpError: (controller, error) {
        log.info('SVG WebView HTTP error: ${error.response?.statusCode}');
        setState(() {
          _webviewLoadFailed = true;
        });
        widget.onError?.call();
      },
    );
  }
}

class SvgNotSupported {
  final String svgData;

  SvgNotSupported(this.svgData);
}
