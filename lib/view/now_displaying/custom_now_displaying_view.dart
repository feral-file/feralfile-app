import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class CustomNowDisplayingView extends StatelessWidget {
  const CustomNowDisplayingView({
    required this.builder,
    this.device,
    super.key,
    this.customAction = const [],
  });

  final Widget Function(BuildContext) builder;
  final BaseDevice? device;
  final List<Widget> customAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      constraints: const BoxConstraints(
        maxHeight: kNowDisplayingHeight,
        minHeight: kNowDisplayingHeight,
      ),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: builder(context),
          ),
          const SizedBox(width: 10),
          ...customAction
              .map(
                (action) => [
                  const SizedBox(width: 5),
                  action,
                  const SizedBox(width: 5),
                ],
              )
              .flattened,
        ],
      ),
    );
  }
}
