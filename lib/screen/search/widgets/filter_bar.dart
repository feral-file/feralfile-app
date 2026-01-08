//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/search/widgets/filter_dialog.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.selectedFilterType,
    required this.onFilterTypeChanged,
    required this.availableTypes,
    required this.sortOrder,
    required this.onSortOrderChanged,
    required this.result,
    required this.selectedFilters,
    required this.onFilterToggled,
    super.key,
  });

  final SearchFilterType selectedFilterType;
  final void Function(SearchFilterType) onFilterTypeChanged;
  final List<SearchFilterType> availableTypes;
  final SearchSortOrder sortOrder;
  final void Function(SearchSortOrder) onSortOrderChanged;
  final MeiliSearchResult? result;
  final List<MeiliFilterSelection> selectedFilters;
  final void Function(
          SearchFilterType type, List<MeiliFilterSelection> selections)
      onFilterToggled;

  @override
  Widget build(BuildContext context) {
    final typeOptions = availableTypes.toList();

    if (typeOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentType = typeOptions.firstWhere(
      (type) => type == selectedFilterType,
      orElse: () => typeOptions.first,
    );

    final sortOptions = selectedFilterType.allowedSortOrders;
    final currentSortLabel = sortOrder.label;
    final supportedFilters = currentType.supportedFilters;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: LayoutConstants.space3,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () async {
                  final optionItems = typeOptions
                      .map(
                        (type) => OptionItem(
                          title: type.label,
                          onTap: () {
                            Navigator.of(context).pop();
                            if (type != selectedFilterType) {
                              onFilterTypeChanged(type);
                            }
                          },
                        ),
                      )
                      .toList();

                  await UIHelper.showCenterMenu(
                    context,
                    options: optionItems,
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: LayoutConstants.space3,
                    vertical: LayoutConstants.space2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentType.label,
                      style: AppTypography.body(context).white,
                    ),
                    SizedBox(width: LayoutConstants.space1),
                    Icon(
                      Icons.expand_more,
                      size: LayoutConstants.iconSizeDefault,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              if (supportedFilters.isNotEmpty) ...[
                SizedBox(width: LayoutConstants.space2),
                TextButton(
                  onPressed: () async {
                    final availableFilters = _getAvailableFiltersForType(
                      result,
                      selectedFilterType,
                    );

                    final selectionsForType = selectedFilters;

                    final updatedSelections = await FilterDialog.show(
                      context,
                      availableFilters: availableFilters,
                      selectedFilters: selectionsForType,
                      filterType: selectedFilterType,
                    );

                    if (updatedSelections == null) {
                      return;
                    }

                    onFilterToggled(selectedFilterType, updatedSelections);
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: LayoutConstants.space3,
                      vertical: LayoutConstants.space2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filter',
                        style: AppTypography.body(context).white,
                      ),
                      SizedBox(width: LayoutConstants.space1),
                      Icon(
                        Icons.tune,
                        size: LayoutConstants.iconSizeDefault,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (sortOptions.length > 1)
                TextButton(
                  onPressed: () async {
                    final optionItems = sortOptions
                        .map(
                          (order) => OptionItem(
                            title: order.label,
                            onTap: () {
                              Navigator.of(context).pop();
                              if (order != sortOrder) {
                                onSortOrderChanged(order);
                              }
                            },
                          ),
                        )
                        .toList();

                    await UIHelper.showCenterMenu(
                      context,
                      options: optionItems,
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: LayoutConstants.space3,
                      vertical: LayoutConstants.space2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSortLabel,
                        style: AppTypography.body(context).white,
                      ),
                      SizedBox(width: LayoutConstants.space1),
                      Icon(
                        Icons.expand_more,
                        size: LayoutConstants.iconSizeDefault,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<MeiliFilterSelection> _getAvailableFiltersForType(
    MeiliSearchResult? result,
    SearchFilterType filterType,
  ) {
    if (result == null) {
      return [];
    }

    switch (filterType) {
      case SearchFilterType.channels:
        return result.channels.getAvailableFilters();
      case SearchFilterType.playlists:
        return result.playlists.getAvailableFilters();
      case SearchFilterType.items:
        return result.works.getAvailableFilters();
      case SearchFilterType.nftTokens:
        return result.nftTokens.getAvailableFilters();
    }
  }
}
