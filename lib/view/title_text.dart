import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:flutter/material.dart';

class TitleText extends StatelessWidget {
  const TitleText({
    required this.title,
    super.key,
    this.ellipsis = true,
    this.isCentered = false,
  });

  final String title;
  final bool isCentered;
  final bool ellipsis;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: AppTypography.h2(context).white,
        maxLines: ellipsis ? null : 2,
        overflow: ellipsis ? TextOverflow.ellipsis : null,
        textAlign: isCentered ? TextAlign.center : null,
      );
}
