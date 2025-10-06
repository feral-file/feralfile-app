import 'package:flutter/material.dart';

class ExpandableWithOption extends StatefulWidget {
  final Widget Function(BuildContext context, VoidCallback? onUpdate,
      ValueNotifier<bool> isExpandedNotifier) header;
  final ValueNotifier<bool> isExpandedNotifier;

  const ExpandableWithOption({
    required this.header,
    required this.isExpandedNotifier,
  });

  @override
  State<ExpandableWithOption> createState() => _ExpandableWithOptionState();
}

class _ExpandableWithOptionState extends State<ExpandableWithOption> {
  @override
  void initState() {
    super.initState();
  }

  void _toggle() {
    widget.isExpandedNotifier.value = !widget.isExpandedNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.isExpandedNotifier,
      builder: (context, value, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
                child:
                    widget.header(context, _toggle, widget.isExpandedNotifier)),
          ],
        );
      },
    );
  }
}
