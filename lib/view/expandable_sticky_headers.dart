import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sliver_sticky_collapsable_panel/sliver_sticky_collapsable_panel.dart';

class ExpandableSliverStickyHeader extends StatefulWidget {
  final Widget header;
  final Widget sliver;
  final bool initiallyExpanded;
  final void Function(bool)? onExpandedChanged;
  final ScrollController scrollController;
  final List<CustomSlidableAction> slidableActions;

  const ExpandableSliverStickyHeader({
    required this.header,
    required this.sliver,
    required this.scrollController,
    super.key,
    this.initiallyExpanded = true,
    this.onExpandedChanged,
    this.slidableActions = const [],
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
    final icon = SvgPicture.asset(
      'assets/images/chevron_left_icon.svg',
      colorFilter: ColorFilter.mode(AppColor.white, BlendMode.srcIn),
      width: 9,
    );
    return SliverStickyCollapsablePanel(
      scrollController: widget.scrollController,
      controller: StickyCollapsablePanelController(),
      headerBuilder:
          (BuildContext context, SliverStickyCollapsablePanelStatus status) {
        final turn = !status.isExpanded ? 0 : 3;
        final noSlidableHeader = Column(
          children: [
            Container(
              color: AppColor.auGreyBackground,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: widget.header),
                  const SizedBox(width: 8),
                  // RotatedBox is used to rotate the icon when the header is collapsed with icon rotation animation
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: status.isExpanded ? -0.25 : 0,
                    child: icon,
                  ),
                ],
              ),
            ),
            if (!status.isExpanded)
              Divider(color: AppColor.primaryBlack, height: 1),
          ],
        );
        final slidableHeader = Slidable(
          groupTag: widget.header.key.toString(),
          endActionPane: ActionPane(
            extentRatio: 88 / 392,
            motion: const DrawerMotion(),
            children: widget.slidableActions,
          ),
          child: noSlidableHeader,
        );
        final header = widget.slidableActions.isNotEmpty
            ? slidableHeader
            : noSlidableHeader;
        return header;
      },
      sliverPanel: widget.sliver,
      expandCallback: widget.onExpandedChanged,
    );
  }
}
