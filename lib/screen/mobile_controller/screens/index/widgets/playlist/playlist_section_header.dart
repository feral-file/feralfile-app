import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/components/PlaylistSectionHeader.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Playlist Section Header - Displays section name with view all button
class PlaylistSectionHeader extends StatelessWidget {
  const PlaylistSectionHeader({
    required this.sectionName,
    this.sectionIcon,
    this.onViewAllTap,
    this.hasMore = true,
    super.key,
  });

  final String sectionName;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
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
                    width: LayoutConstants.iconSizeDefault,
                    height: LayoutConstants.iconSizeDefault,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFFFFFFF),
                      BlendMode.srcIn,
                    ),
                  ),
              SizedBox(
                width: LayoutConstants.space4,
              ),
              Text(
                sectionName,
                style: AppTypography.h4(context).white,
              ),
            ],
          ),
          // Right: View all button
          if (hasMore)
            GestureDetector(
              onTap: onViewAllTap,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 9.78,
                  minHeight: 8,
                ),
                color: Colors.transparent,
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
                    const SizedBox(
                      width: PlaylistSectionHeaderTokens.buttonGap,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 1),
                      child: Text(
                        'All',
                        style: AppTypography.body(context).grey,
                      ),
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
