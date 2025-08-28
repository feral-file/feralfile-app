import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';

final ValueNotifier<bool> isNowDisplayingBarExpanded = ValueNotifier(false);

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
    if (_controller.size > midSize) {
      isNowDisplayingBarExpanded.value = true;
    } else {
      isNowDisplayingBarExpanded.value = false;
    }
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
                          child: widget.collapsedBuilder(
                              context, scrollController),
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: scrollController,
                        ),
                );
              },
            ),
            Positioned(
              top: 5,
              left: 0,
              right: 0,
              child: Center(child: _icon(context)),
            ),
          ],
        );
      },
    );
  }

  Widget _icon(BuildContext context) {
    return Container(
      height: 2,
      width: 30,
      decoration: BoxDecoration(
        color: AppColor.auLightGrey,
        borderRadius: BorderRadius.circular(50),
      ),
    );
  }
}
