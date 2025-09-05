import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';

/// Default of loading state widget
class LoadingWidget extends StatelessWidget {
  final bool invertColors;
  final Color? backgroundColor;
  final Alignment alignment;
  final EdgeInsets padding;
  final bool isInfinitySize;

  const LoadingWidget(
      {super.key,
      this.invertColors = false,
      this.backgroundColor,
      this.alignment = Alignment.center,
      this.padding = EdgeInsets.zero,
      this.isInfinitySize = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: isInfinitySize ? double.infinity : null,
      height: isInfinitySize ? double.infinity : null,
      color: backgroundColor ?? AppColor.primaryBlack,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GifView.asset(
                'assets/images/loading_white.gif',
                height: 52,
                frameRate: 12,
                invertColors: invertColors,
              ),
              const SizedBox(height: 12),
              Text('loading', style: theme.textTheme.ppMori400White12)
            ],
          ),
        ),
      ),
    );
  }
}
