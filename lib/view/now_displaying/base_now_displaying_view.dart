import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class NowDisplayingView extends StatelessWidget {
  const NowDisplayingView({
    required this.thumbnailBuilder,
    required this.titleBuilder,
    required this.artistBuilder,
    required this.device,
    super.key,
    this.customAction = const [],
  });

  final Widget Function(BuildContext) thumbnailBuilder;
  final Widget Function(BuildContext) titleBuilder;
  final Widget Function(BuildContext) artistBuilder;
  final BaseDevice device;
  final List<Widget> customAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 65, minWidth: 65),
            child: thumbnailBuilder(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.name,
                  style: theme.textTheme.ppMori700Black14.copyWith(
                    fontSize: 6,
                  ),
                ),
                Expanded(
                  child: artistBuilder(context),
                ),
                Expanded(child: titleBuilder(context)),
              ],
            ),
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
