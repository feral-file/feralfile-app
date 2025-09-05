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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_snapSheet);
  }

  void _snapSheet() {
    final midSize = (widget.minSize + widget.maxSize) / 2;
    if (_controller.size > widget.minSize * 2) {
      isNowDisplayingBarExpanded.value = true;
    } else {
      isNowDisplayingBarExpanded.value = false;
    }
  }

  void collapseSheet() {
    _controller.animateTo(
      widget.minSize,
      duration: const Duration(milliseconds: 150),
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_snapSheet);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
