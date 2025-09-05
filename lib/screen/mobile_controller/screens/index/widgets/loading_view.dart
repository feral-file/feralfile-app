import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: LoadingWidget(
        backgroundColor: AppColor.auGreyBackground,
      ),
    );
  }
}
