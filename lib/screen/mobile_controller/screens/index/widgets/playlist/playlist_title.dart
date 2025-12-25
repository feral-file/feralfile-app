import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/components/PlaylistListItem.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Playlist List Item - Displays playlist info with primary and secondary text
class PlaylistTitle extends StatelessWidget {
  const PlaylistTitle({
    required this.primaryText,
    required this.secondaryText,
    this.primaryTextSuffix,
    this.onTap,
    super.key,
  });

  final String primaryText;
  final String? primaryTextSuffix;
  final String secondaryText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          primaryText,
                          style: AppTypography.body(context).white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(width: LayoutConstants.space2),
                        Text(
                          primaryTextSuffix ?? '',
                          style: AppTypography.bodySmall(context).grey.italic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: LayoutConstants.space2),
                  Text(
                    secondaryText,
                    style: AppTypography.body(context).italic.grey,
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
