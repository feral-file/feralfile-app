//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FilterDialog {
  const FilterDialog._();

  static Future<List<MeiliFilterSelection>?> show(
    BuildContext context, {
    required List<MeiliFilterSelection> availableFilters,
    required List<MeiliFilterSelection> selectedFilters,
    required SearchFilterType filterType,
  }) async {
    final result = await UIHelper.showCustomCenterDialog(
      context,
      content: _FilterDialogContent(
        availableFilters: availableFilters,
        selectedFilters: selectedFilters,
        filterType: filterType,
      ),
    );

    if (result is List<MeiliFilterSelection>) {
      return result;
    }

    return null;
  }
}

class _FilterDialogContent extends StatefulWidget {
  const _FilterDialogContent({
    required this.availableFilters,
    required this.selectedFilters,
    required this.filterType,
  });

  final List<MeiliFilterSelection> availableFilters;
  final List<MeiliFilterSelection> selectedFilters;
  final SearchFilterType filterType;

  @override
  State<_FilterDialogContent> createState() => _FilterDialogContentState();
}

class _FilterDialogContentState extends State<_FilterDialogContent> {
  late Map<SearchFilterBy, Set<String>> _localSelectedFilters;

  @override
  void initState() {
    super.initState();
    // Initialize local state from selectedFilters
    _localSelectedFilters = {};
    for (final selectedFilter in widget.selectedFilters) {
      _localSelectedFilters[selectedFilter.filterBy] =
          Set<String>.from(selectedFilter.value);
    }
  }

  void _toggleFilter(SearchFilterBy filterBy, String value) {
    setState(() {
      _localSelectedFilters.putIfAbsent(filterBy, () => <String>{});
      final filterSet = _localSelectedFilters[filterBy]!;
      if (filterSet.contains(value)) {
        filterSet.remove(value);
      } else {
        filterSet.add(value);
      }
    });
  }

  void _applyFilters() {
    final updatedSelections = <MeiliFilterSelection>[];

    for (final entry in _localSelectedFilters.entries) {
      if (entry.value.isNotEmpty) {
        updatedSelections.add(
          MeiliFilterSelection(
            filterBy: entry.key,
            value: entry.value,
          ),
        );
      }
    }

    Navigator.pop(context, updatedSelections);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filter', style: AppTypography.h4(context).white),
        SizedBox(height: LayoutConstants.space4),
        Expanded(
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverList.separated(
                itemBuilder: (context, index) {
                  final availableFilter = widget.availableFilters[index];
                  final localSelected =
                      _localSelectedFilters[availableFilter.filterBy] ??
                          <String>{};
                  final selectedFilter = MeiliFilterSelection(
                    filterBy: availableFilter.filterBy,
                    value: localSelected,
                  );
                  return _buildFilterSelection(
                      context, availableFilter, selectedFilter);
                },
                separatorBuilder: (context, index) =>
                    addOnlyDivider(color: AppColor.auLightGrey),
                itemCount: widget.availableFilters.length,
              ),
            ],
          ),
        ),
        SizedBox(height: LayoutConstants.space3),
        Row(
          children: [
            Expanded(
              child: PrimaryAsyncButton(
                onTap: () => Navigator.pop(context),
                text: 'Cancel',
                color: AppColor.auGreyBackground,
                borderColor: AppColor.white,
                textColor: AppColor.white,
              ),
            ),
            SizedBox(width: LayoutConstants.space2),
            Expanded(
              child: PrimaryAsyncButton(
                onTap: _applyFilters,
                text: 'Apply',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSelection(
      BuildContext context,
      MeiliFilterSelection availableFilter,
      MeiliFilterSelection selectedFilter) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: LayoutConstants.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(availableFilter.filterBy.label,
              style: AppTypography.bodyBold(context).white),
          SizedBox(height: LayoutConstants.space2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: availableFilter.value.map((value) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: LayoutConstants.space4,
                    ),
                    child: _FilterDialogItem(
                      option: _FilterOptionItem(
                        title: value,
                        isSelected: selectedFilter.value.contains(value),
                        isEnabled: availableFilter.value.length > 1,
                        onTap: () =>
                            _toggleFilter(availableFilter.filterBy, value),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterOptionItem {
  const _FilterOptionItem({
    required this.title,
    required this.isSelected,
    required this.isEnabled,
    this.onTap,
  });

  final String title;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isEnabled;
}

class _FilterDialogItem extends StatelessWidget {
  const _FilterDialogItem({
    required this.option,
  });

  final _FilterOptionItem option;

  @override
  Widget build(BuildContext context) {
    final selectedStyle = AppTypography.bodyBold(context).white;
    final unselectedStyle = AppTypography.body(context).grey;
    final child = Text(option.title,
        style: option.isSelected || !option.isEnabled
            ? selectedStyle
            : unselectedStyle);

    return GestureDetector(
      onTap: option.isEnabled ? option.onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: LayoutConstants.space2,
        ),
        child: child,
      ),
    );
  }
}
