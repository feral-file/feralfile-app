import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';

class FFTitleRow extends StatelessWidget {
  const FFTitleRow({
    required this.title,
    super.key,
    this.onTap,
    this.dividerColor = AppColor.primaryBlack,
  });
  final Function()? onTap;
  final String title;
  final Color dividerColor;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: Colors.transparent,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveLayout.paddingHorizontal,
                vertical: 16,
              ),
              child: Row(
                children: [
                  // Playlist info
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.ppMori400White12,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: dividerColor,
            ),
          ],
        ),
      ),
    );
  }
}
