import 'package:autonomy_flutter/design/build/components/HomeIndexHeader.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

/// Home Index Header - Navigation tabs with hamburger menu
class HomeIndexHeader extends StatelessWidget {
  const HomeIndexHeader({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  final HomeIndexTab selectedTab;
  final void Function(HomeIndexTab) onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeIndexHeaderTokens.paddingHorizontal,
        vertical: HomeIndexHeaderTokens.paddingVertical,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tabs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: HomeIndexTab.values.map((tab) {
              final isSelected = tab == selectedTab;
              return GestureDetector(
                onTap: () => onTabChanged(tab),
                child: Padding(
                  padding: const EdgeInsets.only(right: 11),
                  child: Text(
                    tab.label,
                    style: isSelected
                        ? theme.textTheme.ppMori400White12
                        : theme.textTheme.ppMori400Grey12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

enum HomeIndexTab {
  playlists('Playlists'),
  channels('Channels'),
  works('Works');

  final String label;
  const HomeIndexTab(this.label);
}
