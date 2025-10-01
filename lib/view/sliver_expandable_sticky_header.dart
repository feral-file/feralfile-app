import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

class SliverExpandableStickyHeader extends StatefulWidget {
  final Widget header;
  final Widget Function(BuildContext) sliverBuilder;
  final bool initiallyExpanded;
  final void Function(bool) onExpandedChanged;

  const SliverExpandableStickyHeader({
    super.key,
    required this.header,
    required this.sliverBuilder,
    this.initiallyExpanded = true,
    required this.onExpandedChanged,
  });

  @override
  State<SliverExpandableStickyHeader> createState() =>
      _SliverExpandableStickyHeaderState();
}

class _SliverExpandableStickyHeaderState
    extends State<SliverExpandableStickyHeader> {
  late bool isExpanded;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() {
      isExpanded = !isExpanded;
    });
    widget.onExpandedChanged(isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return SliverStickyHeader(
      header: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: widget.header),
              const SizedBox(width: 8),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
      sliver: isExpanded
          ? widget.sliverBuilder(context)
          : const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}
