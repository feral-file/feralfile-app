import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class FeralfileBanner extends StatelessWidget {
  final Function? onClose;
  final Function? onGetStarted;
  final String title;
  final String? buttonText;

  const FeralfileBanner(
      {required this.title,
      super.key,
      this.onGetStarted,
      this.onClose,
      this.buttonText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColor.auGreyBackground),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.ppMori400White14,
                  maxLines: 2,
                ),
              ),
              if (onClose != null)
                GestureDetector(
                  onTap: () {
                    onClose?.call();
                  },
                  child: const Icon(
                    size: 18,
                    AuIcon.close,
                    color: AppColor.white,
                  ),
                  //padding: EdgeInsets.zero,
                )
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          PrimaryAsyncButton(
            onTap: () {
              onGetStarted?.call();
            },
            text: buttonText ?? 'get_started'.tr(),
          )
        ],
      ),
    );
  }
}
