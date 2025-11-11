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
          widget.minSize,
          duration: duration,
          curve: Curves.easeOut,
        );
        log.info("Sheet collapsed to minSize: ${_controller.size}");
      } catch (e) {
        log.info("Error collapsing sheet: $e");
      } finally {
        _isAdjustingSize = false;
        if (!completer.isCompleted) {
          completer.complete();
        }
        _snapSheet();
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

      // Only adjust when collapsed or when current size is below new minSize
      final bool shouldClampToMin =
          !isCurrentlyExpanded || _controller.size < widget.minSize;

      if (shouldClampToMin) {
        _isAdjustingSize = true;
        final double distance = (widget.minSize - _controller.size).abs();
        final int ms = (120 + distance * 200).clamp(80, 300).toInt();
        collapseSheet(duration: Duration(milliseconds: ms));
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
      // Avoid providing a new GlobalKey on each build; this preserves state
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
