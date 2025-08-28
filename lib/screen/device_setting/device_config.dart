import 'dart:async';

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class DeviceConfigItem {
  DeviceConfigItem({
    required this.title,
    required this.icon,
    this.titleStyle,
    this.titleStyleOnUnselected,
    this.iconOnUnselected,
    this.onSelected,
    this.onUnselected,
  });

  final String title;
  final TextStyle? titleStyle;
  final TextStyle? titleStyleOnUnselected;
  final Widget icon;
  final Widget? iconOnUnselected;

  final FutureOr<void> Function()? onSelected;
  final FutureOr<void> Function()? onUnselected;
}

class SelectDeviceConfigView extends StatefulWidget {
  const SelectDeviceConfigView({
    required this.items,
    required this.selectedIndex,
    super.key,
    this.isEnable = true,
    this.itemCustomBuilder,
  });

  final List<DeviceConfigItem> items;
  final int selectedIndex;
  final bool isEnable;
  final Widget Function(DeviceConfigItem item, bool isSelected)?
      itemCustomBuilder;

  @override
  State<SelectDeviceConfigView> createState() => SelectItemState();
}

class SelectItemState extends State<SelectDeviceConfigView> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant SelectDeviceConfigView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: widget.items.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final isSelected = _selectedIndex == index && widget.isEnable;
        if (widget.itemCustomBuilder != null) {
          return widget.itemCustomBuilder!(item, isSelected);
        }
        final activeTitleStyle =
            item.titleStyle ?? Theme.of(context).textTheme.ppMori400White14;
        final deactiveTitleStyle =
            item.titleStyleOnUnselected ?? activeTitleStyle;
        final titleStyle = isSelected ? activeTitleStyle : deactiveTitleStyle;
        return GestureDetector(
          onTap: () async {
            if (!widget.isEnable) {
              return;
            }

            final currentIndex = _selectedIndex;

            setState(() {
              _selectedIndex = index;
            });

            try {
              await item.onSelected?.call();
            } catch (e) {
              if (mounted) {
                setState(() {
                  _selectedIndex = currentIndex;
                });
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColor.white : AppColor.disabledColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.icon,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SvgPicture.asset(
                    isSelected
                        ? 'assets/images/check_box_true.svg'
                        : 'assets/images/check_box_false.svg',
                    height: 12,
                    width: 12,
                    colorFilter: const ColorFilter.mode(
                      AppColor.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.title,
                      style: titleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
