import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:sliver_sticky_collapsable_panel/sliver_sticky_collapsable_panel.dart';

class ExpandableSliverStickyHeader extends StatefulWidget {
  final Widget header;
  final Widget sliver;
  final bool initiallyExpanded;
  final void Function(bool)? onExpandedChanged;
  final ScrollController scrollController;

  const ExpandableSliverStickyHeader({
    super.key,
    required this.header,
    required this.sliver,
    this.initiallyExpanded = true,
    this.onExpandedChanged,
    required this.scrollController,
  });

  @override
  State<ExpandableSliverStickyHeader> createState() =>
      _ExpandableSliverStickyHeaderState();
}

class _ExpandableSliverStickyHeaderState
    extends State<ExpandableSliverStickyHeader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SliverStickyCollapsablePanel(
      scrollController: widget.scrollController,
      controller: StickyCollapsablePanelController(),
      headerBuilder:
          (BuildContext context, SliverStickyCollapsablePanelStatus status) {
        return Container(
          color: AppColor.auGreyBackground,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          alignment: Alignment.centerLeft,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: widget.header),
                  const SizedBox(width: 8),
                  Icon(
                    status.isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
              if (status.isPinned)
                Divider(color: AppColor.primaryBlack, height: 1),
            ],
          ),
        );
      },
      sliverPanel: widget.sliver,
      expandCallback: widget.onExpandedChanged,
    );
  }
}
