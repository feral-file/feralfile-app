import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/components/PlaylistListItem.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

/// Playlist List Item - Displays playlist info with primary and secondary text
class PlaylistTitle extends StatelessWidget {
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    this.onTap,
    super.key,
  });

  final String primaryText;
  final String secondaryText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: PlaylistListItemTokens.paddingHorizontal,
          vertical: PlaylistListItemTokens.paddingVertical,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    primaryText,
                    style: AppTypography.body(context).bold.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    secondaryText,
                    style: AppTypography.bodySmall(context).italic.grey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
