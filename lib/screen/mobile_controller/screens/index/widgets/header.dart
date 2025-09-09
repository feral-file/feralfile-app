import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';

const List<String> pageTitles = [
  'Playlists',
  'Channels',
  'Works',
  'Explore',
];

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({
    required this.selectedIndex,
    required this.onPageChanged,
    super.key,
  });

  final int selectedIndex;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: pageTitles.map((title) {
        final index = pageTitles.indexOf(title);
        return _headerButton(
          context,
          title,
          index,
        );
      }).toList(),
    );
  }

  Widget _headerButton(BuildContext context, String title, int index) {
    final theme = Theme.of(context);
    final isSelected = selectedIndex == index;

    return TextButton(
      onPressed: () {
        onPageChanged(index);
      },
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: ResponsiveLayout.paddingHorizontal,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
      ),
      child: Text(
        title,
        style: isSelected
            ? theme.textTheme.ppMori400White12
            : theme.textTheme.ppMori400Grey12,
      ),
    );
  }
}
