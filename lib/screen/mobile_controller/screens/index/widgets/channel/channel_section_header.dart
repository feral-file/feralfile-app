import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Channel Section Header - Displays section name with view all button
class ChannelSectionHeader extends StatelessWidget {
  const ChannelSectionHeader({
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
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFFFFFFF),
                      BlendMode.srcIn,
                    ),
                  ),
              const SizedBox(
                width: 12,
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
                    width: 9.78,
                    height: 8,
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
                      style: theme.textTheme.ppMori400Grey12,
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


