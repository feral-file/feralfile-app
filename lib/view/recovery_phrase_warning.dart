import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class RecoveryPhraseWarning extends StatelessWidget {
  const RecoveryPhraseWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<String>>>(
      future: ChannelService().exportMnemonicForAllPersonaUUIDs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox();
        }

        if (snapshot.hasError) {
          return const SizedBox();
        }

        final mnemonicMap = snapshot.data!;

        if (mnemonicMap.isEmpty) {
          return const SizedBox();
        }

        return Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColor.feralFileHighlight,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'important_update'.tr(),
                      style: AppTypography.body(context).bold.black,
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: AppTypography.body(context).black,
                        children: [
                          TextSpan(
                            text: '${'get_recovery_phrase_desc'.tr()} ',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: 'get_recovery_phrase'.tr(),
                      color: AppColor.feralFileLightBlue,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRouter.recoveryPhrasePage,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
