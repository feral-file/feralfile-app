import 'package:autonomy_flutter/design/build/components/PlaylistSectionHeader.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Playlist Section Header - Displays section name with view all button
class PlaylistSectionHeader extends StatelessWidget {
  const PlaylistSectionHeader({
    required this.sectionName,
    this.sectionIcon,
    this.onViewAllTap,
    super.key,
  });

  final String sectionName;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PlaylistSectionHeaderTokens.paddingHorizontal,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Section name with icon
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              sectionIcon ??
                  SvgPicture.asset(
                    'assets/images/icon_account.svg',
                    width: PlaylistSectionHeaderTokens.sectionIconWidth,
                    height: PlaylistSectionHeaderTokens.sectionIconHeight,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFFFFFFF),
                      BlendMode.srcIn,
                    ),
                  ),
              SizedBox(
                width: PlaylistSectionHeaderTokens.sectionGap,
              ),
              Text(
                sectionName,
                style: theme.textTheme.ppMori400Grey12,
              ),
            ],
          ),
          // Right: View all button
          GestureDetector(
            onTap: onViewAllTap,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/icon_arrow_left.svg',
                    width: PlaylistSectionHeaderTokens.viewAllIconWidth,
                    height: PlaylistSectionHeaderTokens.viewAllIconHeight,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFA0A0A0),
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(
                    width: PlaylistSectionHeaderTokens.buttonGap,
                  ),
                  Text(
                    'All',
                    style: theme.textTheme.ppMori400Grey12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
