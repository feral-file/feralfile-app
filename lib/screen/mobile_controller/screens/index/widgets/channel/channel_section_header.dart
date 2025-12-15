import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Channel Section Header - Displays section name with view all button
class ChannelSectionHeader extends StatelessWidget {
  const ChannelSectionHeader({
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
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
                    width: LayoutConstants.iconSizeMedium,
                    height: LayoutConstants.iconSizeMedium,
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
                style: AppTypography.h3(context).white,
              ),
            ],
          ),
          // Right: View all button
          if (hasMore)
            GestureDetector(
              onTap: onViewAllTap,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: LayoutConstants.iconSizeSmall,
                  minHeight: LayoutConstants.iconSizeSmall,
                ),
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/images/icon_arrow_left.svg',
                      width: LayoutConstants.iconSizeSmall,
                      height: LayoutConstants.iconSizeSmall,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFA0A0A0),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
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
