import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:flutter/material.dart';

class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({
    required this.isLoadingMore,
    super.key,
  });

  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: isLoadingMore
          ? const LoadingWidget(
              backgroundColor: AppColor.auGreyBackground,
            )
          : const SizedBox.shrink(),
    );
  }
}
