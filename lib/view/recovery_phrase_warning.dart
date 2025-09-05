import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
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
                      style: Theme.of(context).textTheme.ppMori700Black16,
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.ppMori400Black14,
                        children: [
                          TextSpan(
                            text: '${'get_recovery_phrase_desc'.tr()} ',
                          ),
                          TextSpan(
                            text: 'read_more'.tr(),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                injector<VersionService>().showReleaseNotes();
                              },
                            style: const TextStyle(
                              color: AppColor.primaryBlack,
                              decoration: TextDecoration.underline,
                            ),
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
