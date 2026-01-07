//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.selectedFilterType,
    required this.onFilterTypeChanged,
    required this.hasChannels,
    required this.hasPlaylists,
    required this.hasItems,
    required this.hasNftTokens,
    super.key,
  });

  final SearchFilterType selectedFilterType;
  final void Function(SearchFilterType) onFilterTypeChanged;
  final bool hasChannels;
  final bool hasPlaylists;
  final bool hasItems;
  final bool hasNftTokens;

  @override
  Widget build(BuildContext context) {
    final options = <_FilterTypeOption>[];

    if (hasPlaylists) {
      options.add(
        const _FilterTypeOption(
          type: SearchFilterType.playlists,
          label: 'Playlists',
        ),
      );
    }

    if (hasChannels) {
      options.add(
        const _FilterTypeOption(
          type: SearchFilterType.channels,
          label: 'Channels',
        ),
      );
    }

    if (hasItems) {
      options.add(
        const _FilterTypeOption(
          type: SearchFilterType.items,
          label: 'Works',
        ),
      );
    }

    if (hasNftTokens) {
      options.add(
        const _FilterTypeOption(
          type: SearchFilterType.nftTokens,
          label: 'Collections',
        ),
      );
    }

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    final current =
        options.firstWhere((o) => o.type == selectedFilterType, orElse: () {
      return options.first;
    });

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: LayoutConstants.space3,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () async {
            final optionItems = options
                .map(
                  (o) => OptionItem(
                    title: o.label,
                    onTap: () {
                      Navigator.of(context).pop();
                      if (o.type != selectedFilterType) {
                        onFilterTypeChanged(o.type);
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
                '${current.label}',
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
      ),
    );
  }
}

class _FilterTypeOption {
  const _FilterTypeOption({
    required this.type,
    required this.label,
  });

  final SearchFilterType type;
  final String label;
}
