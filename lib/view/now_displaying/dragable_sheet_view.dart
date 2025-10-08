import 'dart:async';

import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/material.dart';

final ValueNotifier<bool> isNowDisplayingBarExpanded = ValueNotifier(false);

final GlobalKey<_TwoStopDraggableSheetState> draggableSheetKey =
    GlobalKey<_TwoStopDraggableSheetState>();

class TwoStopDraggableSheet extends StatefulWidget {
  final double minSize;
  final double maxSize;
  final Widget Function(BuildContext, ScrollController) collapsedBuilder;
  final Widget Function(BuildContext, ScrollController) expandedBuilder;

  const TwoStopDraggableSheet({
    required this.minSize,
    required this.maxSize,
    required this.collapsedBuilder,
    required this.expandedBuilder,
    super.key,
  });

  @override
  State<TwoStopDraggableSheet> createState() => _TwoStopDraggableSheetState();
}

class _TwoStopDraggableSheetState extends State<TwoStopDraggableSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  Timer? _timer;
  bool _isAdjustingSize =
      false; // guard to ignore listener during programmatic size adjustments

  @override
  void initState() {
    super.initState();
    _controller.addListener(_snapSheet);
  }

  void _snapSheet() {
    if (_isAdjustingSize) {
      return; // ignore snaps while we're programmatically adjusting size
    }
    final midSize = (widget.minSize + widget.maxSize) / 2;
    if (_controller.size > widget.minSize * 2 || _controller.size >= midSize) {
      isNowDisplayingBarExpanded.value = true;
    } else {
      isNowDisplayingBarExpanded.value = false;
    }
    log.info(
        "Sheet size: ${_controller.size}, isNowDisplayingBarExpanded: ${isNowDisplayingBarExpanded.value}, minSize: ${widget.minSize}, maxSize: ${widget.maxSize}");
  }

  Future<void> collapseSheet(
      {Duration duration = const Duration(milliseconds: 150)}) async {
    log.info("Collapsing sheet from size: ${_controller.size}");
    log.info("Collapsing sheet to minSize: ${widget.minSize}");
    _isAdjustingSize = true;
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _controller.animateTo(
          0.5,
          duration: Duration(seconds: 5),
          curve: Curves.linear,
        );
        log.info("Sheet collapsed to minSize: ${_controller.size}");
      } finally {
        _isAdjustingSize = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    await completer.future;
  }

  @override
  void didUpdateWidget(covariant TwoStopDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If minSize has changed (e.g., collapsed settings shown/hidden), clamp the sheet
    // to the new minSize when currently in collapsed state, to avoid unintended expand.
    if (widget.minSize != oldWidget.minSize) {
      final bool isCurrentlyExpanded = isNowDisplayingBarExpanded.value;

      if (!isCurrentlyExpanded) {
        _isAdjustingSize = true;
        // Jump immediately to the new min size to keep the visual state consistent
        // without triggering a snap to expanded.
        final diff = _controller.size - widget.minSize;
        final baseDuration = const Duration(milliseconds: 30);
        final duration = Duration(
            milliseconds:
                (baseDuration.inMilliseconds * (diff.abs() * 10)).toInt());
        collapseSheet(duration: duration);
        // Clear the adjusting flag after this frame so listener resumes normally
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_snapSheet);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      key: GlobalKey(),
      controller: _controller,
      initialChildSize: widget.minSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: [widget.minSize, widget.maxSize],
      builder: (context, scrollController) {
        return Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: isNowDisplayingBarExpanded,
              builder: (context, value, child) {
                return Container(
                  child: value
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: scrollController,
                          child: widget.expandedBuilder(
                            context,
                            scrollController,
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: scrollController,
                          child: widget.collapsedBuilder(
                            context,
                            scrollController,
                          ),
                        ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class DraggableSheetController {
  static void collapseSheet() {
    final state = draggableSheetKey.currentState;
    if (state != null) {
      state.collapseSheet();
    }
  }
}
