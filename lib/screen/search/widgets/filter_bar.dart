//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.selectedFilterType,
    required this.onFilterTypeChanged,
    required this.hasChannels,
    required this.hasPlaylists,
    required this.hasItems,
    super.key,
  });

  final SearchFilterType selectedFilterType;
  final void Function(SearchFilterType) onFilterTypeChanged;
  final bool hasChannels;
  final bool hasPlaylists;
  final bool hasItems;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[];

    if (hasChannels) {
      tabs.add(
        _FilterTab(
          label: 'Channels',
          isSelected: selectedFilterType == SearchFilterType.channels,
          onTap: () => onFilterTypeChanged(SearchFilterType.channels),
        ),
      );
    }

    if (hasPlaylists) {
      if (tabs.isNotEmpty) {
        tabs.add(SizedBox(width: LayoutConstants.space3));
      }
      tabs.add(
        _FilterTab(
          label: 'Playlists',
          isSelected: selectedFilterType == SearchFilterType.playlists,
          onTap: () => onFilterTypeChanged(SearchFilterType.playlists),
        ),
      );
    }

    if (hasItems) {
      if (tabs.isNotEmpty) {
        tabs.add(SizedBox(width: LayoutConstants.space3));
      }
      tabs.add(
        _FilterTab(
          label: 'Works',
          isSelected: selectedFilterType == SearchFilterType.items,
          onTap: () => onFilterTypeChanged(SearchFilterType.items),
        ),
      );
    }

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
        vertical: LayoutConstants.space3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: tabs,
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: isSelected
            ? AppTypography.body(context).white
            : AppTypography.body(context).grey,
      ),
    );
  }
}
