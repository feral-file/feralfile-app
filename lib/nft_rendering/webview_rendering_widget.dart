import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/nft_rendering/feralfile_webview.dart';
import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/nft_rendering/webview_controller_ext.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewNFTRenderingWidget extends NFTRenderingWidget {
  final Uri previewUri;
  final String? overriddenHtml;
  final bool isMute;
  final Widget loadingWidget;
  final FocusNode? focusNode;
  final Function(WebViewController)? onLoaded;

  const WebviewNFTRenderingWidget({
    required this.previewUri,
    this.loadingWidget = const LoadingWidget(),
    super.key,
    this.overriddenHtml,
    this.isMute = false,
    this.focusNode,
    this.onLoaded,
  });

  @override
  State<WebviewNFTRenderingWidget> createState() =>
      _WebviewNFTRenderingWidgetState();
}

class _WebviewNFTRenderingWidgetState
    extends NFTRenderingWidgetState<WebviewNFTRenderingWidget>
    with WidgetsBindingObserver {
  ValueNotifier<bool> isPausing = ValueNotifier(false);
  WebViewController? _webViewController;
  final TextEditingController _textController = TextEditingController();
  final Color backgroundColor = Colors.black;
  bool isPreviewLoaded = false;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _updateWebviewSize();
  }

  void _updateWebviewSize() {
    updateWebviewSize();
  }

  @override
  void didUpdateWidget(WebviewNFTRenderingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewUri != widget.previewUri) {
      isPreviewLoaded = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> onPause() async {
    await _webViewController?.evaluateJavascript(
        source: "var video = document.getElementsByTagName('video')[0]; "
            'if(video != undefined) { video.pause(); } '
            "var audio = document.getElementsByTagName('audio')[0]; "
            'if(audio != undefined) { audio.pause(); }');
  }

  Future<void> onResume() async {
    await _webViewController?.evaluateJavascript(
        source: "var video = document.getElementsByTagName('video')[0]; "
            'if(video != undefined) { video.play(); } '
            "var audio = document.getElementsByTagName('audio')[0]; "
            'if(audio != undefined) { audio.play(); }');
  }

  Future<void> pauseOrResume() async {
    if (isPausing.value) {
      await onResume();
    } else {
      await onPause();
    }
    isPausing.value = !isPausing.value;
  }

  @override
  Future<void> mute() async {
    await _webViewController?.evaluateJavascript(
        source: "var video = document.getElementsByTagName('video')[0]; "
            'if(video != undefined) { video.muted = true; } '
            "var audio = document.getElementsByTagName('audio')[0]; "
            'if(audio != undefined) { audio.muted = true; }');
  }

  @override
  Future<void> unmute() async {
    await _webViewController?.evaluateJavascript(
        source: "var video = document.getElementsByTagName('video')[0]; "
            'if(video != undefined) { video.muted = false; } '
            "var audio = document.getElementsByTagName('audio')[0]; "
            'if(audio != undefined) { audio.muted = false; }');
  }

  @override
  Future<void> pause() async {
    await onPause();
  }

  @override
  Future<void> resume() async {
    await onResume();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          _buildWebView(),
          if (!isPreviewLoaded) widget.loadingWidget,
          if (widget.focusNode != null) _buildTextField(),
        ],
      );

  Widget _buildWebView() => FeralFileWebview(
        key: Key('FeralFileWebview_${widget.previewUri.toString()}'),
        uri: widget.overriddenHtml != null
            ? Uri.parse('about:blank')
            : widget.previewUri,
        overriddenHtml: widget.overriddenHtml,
        backgroundColor: backgroundColor,
        onStarted: (WebViewController controller) {
          _webViewController = controller;
          // if (widget.overriddenHtml != null) {
          //   final uri = Uri.dataFromString(widget.overriddenHtml!,
          //       mimeType: 'text/html', encoding: Encoding.getByName('utf-8'));
          //   unawaited(
          //     _webViewController?.loadRequest(uri),
          //   );
          // }
        },
        onLoaded: (controller) async {
          setState(() {
            isPreviewLoaded = true;
          });

          widget.onLoaded?.call(controller);

          String viewportContent =
              Platform.isIOS ? 'width=device-width, initial-scale=1.0' : '';
          String javascriptString = '''
          var viewportmeta = document.querySelector('meta[name="viewport"]');
          if (!viewportmeta) {
            var head = document.getElementsByTagName('head')[0];
            var viewport = document.createElement('meta');
            viewport.setAttribute('name', 'viewport');
            viewport.setAttribute('content', '$viewportContent');
            head.appendChild(viewport);
          }
        ''';
          await _webViewController?.evaluateJavascript(
              source: javascriptString);

          // Check if background color is set
          await _webViewController?.evaluateJavascript(
            source: '''
            if (window.getComputedStyle(document.body).backgroundColor == 'rgba(0, 0, 0, 0)') {
              document.body.style.backgroundColor = 
              'rgba(
                ${backgroundColor.red}, 
                ${backgroundColor.green}, 
                ${backgroundColor.blue}, 
                1
              )';
            }
          ''',
          );

          if (widget.isMute) {
            await mute();
          }
        },
      );

  Widget _buildTextField() => Visibility(
        visible: widget.focusNode != null,
        child: TextFormField(
          controller: _textController,
          focusNode: widget.focusNode,
          onChanged: (value) async {
            if (value.isNotEmpty) {
              await _webViewController?.evaluateJavascript(
                source: '''
                window.dispatchEvent(new KeyboardEvent('keydown', 
                    {'key': '${value.characters.last}',
                    'keyCode': ${keysCode[value.characters.last]},
                    'which': ${keysCode[value.characters.last]}}));
                window.dispatchEvent(new KeyboardEvent('keypress', 
                    {'key': '${value.characters.last}',
                    'keyCode': ${keysCode[value.characters.last]},
                    'which': ${keysCode[value.characters.last]}}));
                window.dispatchEvent(new KeyboardEvent('keyup', 
                    {'key': '${value.characters.last}',
                    'keyCode': ${keysCode[value.characters.last]},
                    'which': ${keysCode[value.characters.last]}}));
              ''',
              );
              _textController.clear(); // Clear the text field after dispatching
            }
          },
        ),
      );

  @override
  void dispose() {
    _textController.dispose();
    _webViewController = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void updateWebviewSize() {
    if (_webViewController != null) {
      EasyDebounce.debounce(
        'screen_rotate', // An ID for this particular debouncer
        const Duration(milliseconds: 100), // The debounce duration
        () => unawaited(
          _webViewController?.evaluateJavascript(
              source: "window.dispatchEvent(new Event('resize'));"),
        ),
      );
    }
  }
}
