import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';

class SplittedBanner extends StatelessWidget {
  final Widget headerWidget;
  final Widget bodyWidget;

  const SplittedBanner(
      {required this.headerWidget, required this.bodyWidget, super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _buildHeader(),
          _buildBody(),
        ],
      );

  Widget _buildHeader() => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColor.auGreyBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          child: headerWidget,
        ),
      );

  Widget _buildBody() => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColor.primaryBlack,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
          child: bodyWidget,
        ),
      );
}
