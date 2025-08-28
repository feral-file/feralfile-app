import 'dart:async';

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/material.dart';

class FilterItem extends StatefulWidget {
  final String type;
  final List<String> values;
  final int? selectedIndex;
  final void Function(int) onFilterSelected;
  final void Function()? onFilterCleared;
  final void Function()? onFilterExpanded;

  const FilterItem({
    required this.type,
    required this.values,
    required this.selectedIndex,
    required this.onFilterSelected,
    this.onFilterCleared,
    this.onFilterExpanded,
    super.key,
  });

  @override
  State<FilterItem> createState() => FilterItemState();
}

class FilterItemState extends State<FilterItem> {
  int? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selectedIndex;
  }

  void _onFilterSelected(String value) {
    final index = widget.values.indexOf(value);
    setState(() {
      _selectedValue = index;
    });
    widget.onFilterSelected(index);
  }

  void _onFilterCleared() {
    setState(() {
      _selectedValue = null;
    });
    widget.onFilterCleared?.call();
  }

  Widget _clearIcon(BuildContext context) => GestureDetector(
        onTap: _onFilterCleared,
        child: const Icon(
          Icons.clear,
          color: AppColor.primaryBlack,
          size: 18,
        ),
      );

  void _showMenu(BuildContext context) {
    final options = widget.values
        .map((e) => OptionItem(
              title: e,
              onTap: () {
                _onFilterSelected(e);
                Navigator.of(context).pop();
              },
            ))
        .toList();
    unawaited(UIHelper.showCenterMenu(context, options: options));
  }

  Widget _unexpandedWidget(BuildContext context) {
    final theme = Theme.of(context);
    final style = _selectedValue == null
        ? theme.textTheme.ppMori400FFQuickSilver12
        : theme.textTheme.ppMori400Black12;
    return Column(
      children: [
        Row(children: [
          GestureDetector(
            onTap: () {
              _showMenu(context);
            },
            child: Text(
              widget.selectedIndex != null
                  ? widget.values[widget.selectedIndex!]
                  : widget.type,
              style: style.copyWith(height: 1.5),
            ),
          ),
          if (widget.onFilterCleared != null && _selectedValue != null) ...[
            const SizedBox(
              width: 4,
            ),
            _clearIcon(context)
          ],
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        _selectedValue == null ? AppColor.auGreyBackground : AppColor.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: backgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _unexpandedWidget(context),
        ],
      ),
    );
  }
}
