import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class EmptyAddressList extends StatelessWidget {
  const EmptyAddressList({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'no_addresses_found'.tr(),
            style: AppTypography.body(context).bold.black,
          ),
          const SizedBox(height: 8),
          Text(
            'add_first_address'.tr(),
            style: AppTypography.body(context).black,
          ),
        ],
      ),
    );
  }
}
