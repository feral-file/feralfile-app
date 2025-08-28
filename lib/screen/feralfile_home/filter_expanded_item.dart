import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:flutter/material.dart';

class FilterExpanandedItem extends StatefulWidget {
  final String type;
  final List<String> values;
  final int? selectedIndex;
  final void Function(int) onFilterSelected;
  final void Function()? onFilterCleared;
  final void Function()? onFilterExpanded;

  const FilterExpanandedItem({
    required this.type,
    required this.values,
    required this.selectedIndex,
    required this.onFilterSelected,
    this.onFilterCleared,
    this.onFilterExpanded,
    super.key,
  });

  @override
  State<FilterExpanandedItem> createState() => FilterExpanandedItemState();
}

class FilterExpanandedItemState extends State<FilterExpanandedItem> {
  int? _selectedValue;
  bool _isExpanded = false;

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
    collapse();
    widget.onFilterSelected(index);
  }

  void _onFilterCleared() {
    setState(() {
      _selectedValue = null;
      _isExpanded = false;
    });
    widget.onFilterCleared?.call();
  }

  Widget _clearIcon(BuildContext context) => GestureDetector(
        onTap: _onFilterCleared,
        child: const Icon(
          Icons.clear,
          color: AppColor.white,
          size: 16,
        ),
      );

  Widget _unexpandedWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(children: [
          GestureDetector(
            onTap: () {
              expand();
            },
            child: Text(
              widget.selectedIndex != null
                  ? widget.values[widget.selectedIndex!]
                  : widget.type,
              style: theme.textTheme.ppMori400White12,
            ),
          ),
          if (widget.onFilterCleared != null) ...[
            const SizedBox(
              width: 8,
            ),
            if (_selectedValue != null)
              _clearIcon(context)
            else
              const SizedBox(),
          ],
        ]),
      ],
    );
  }

  void expand() {
    setState(() {
      _isExpanded = true;
    });
    widget.onFilterExpanded?.call();
  }

  void collapse() {
    setState(() {
      _isExpanded = false;
    });
  }

  Widget _expandedWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header
        Row(
          children: [
            GestureDetector(
              onTap: () {
                collapse();
              },
              child: Text(
                widget.type,
                style: theme.textTheme.ppMori400White12,
              ),
            ),
            if (widget.onFilterCleared != null) ...[
              const SizedBox(
                width: 8,
              ),
              if (_selectedValue != null)
                _clearIcon(context)
              else
                const SizedBox(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _expandedBody(BuildContext context) {
    final theme = Theme.of(context);
    const divider = Divider(
      color: AppColor.white,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.values.map((value) => Column(
              children: [
                GestureDetector(
                  onTap: () {
                    _onFilterSelected(value);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    color: Colors.transparent,
                    child: Text(
                      value,
                      style: theme.textTheme.ppMori400White12,
                    ),
                  ),
                ),
                divider,
              ],
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColor.auGreyBackground,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExpanded)
              _expandedWidget(context)
            else
              _unexpandedWidget(context),
            Visibility(
              visible: _isExpanded,
              child: Column(
                children: [
                  SizedBox(
                    width: 45,
                    child: addDivider(),
                  ),
                  _expandedBody(context),
                ],
              ),
            ),
          ],
        ),
      );
}
