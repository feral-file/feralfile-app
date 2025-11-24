import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:flutter/material.dart';

class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({
    required this.isLoadingMore,
    this.padding,
    this.width,
    this.height,
    this.frameRate,
    this.showText,
    this.text,
    super.key,
  });

  final bool isLoadingMore;
  final EdgeInsets? padding;
  final int? width;
  final int? height;
  final int? frameRate;
  final bool? showText;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: isLoadingMore
          ? LoadingWidget(
              backgroundColor: AppColor.auGreyBackground,
              width: width,
              height: height,
              frameRate: frameRate,
              showText: showText ?? true,
              text: text,
            )
          : const SizedBox.shrink(),
    );
  }
}
