import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

/// Playlist Details Header - Displays playlist info with icon, title badge, and description
class PlaylistDetailsHeader extends StatelessWidget {
  const PlaylistDetailsHeader({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    super.key,
  });

  final Widget icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left section: icon, curated badge, and description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and title badge
                  if (title.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: icon,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: theme.textTheme.ppMori400White12,
                        ),
                      ],
                    ),
                  if (title.isNotEmpty) const SizedBox(height: 20),
                  // Description text
                  Text(
                    description,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.ppMori400Grey12,
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
