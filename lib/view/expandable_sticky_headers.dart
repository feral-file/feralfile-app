import 'package:flutter/material.dart';
import 'package:sticky_headers/sticky_headers.dart';

class ExpandableStickyHeader extends StatefulWidget {
  final Widget header;
  final Widget Function(BuildContext) contentBuilder;
  final bool initiallyExpanded;
  final void Function(bool) onExpandedChanged;

  const ExpandableStickyHeader({
    super.key,
    required this.header,
    required this.contentBuilder,
    this.initiallyExpanded = true,
    required this.onExpandedChanged,
  });

  @override
  State<ExpandableStickyHeader> createState() => _ExpandableStickyHeaderState();
}

class _ExpandableStickyHeaderState extends State<ExpandableStickyHeader> {
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
    return StickyHeader(
      header: GestureDetector(
        onTap: _toggle,
        child: Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
      content: isExpanded
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.contentBuilder(context),
            )
          : SizedBox.shrink(),
    );
  }
}
