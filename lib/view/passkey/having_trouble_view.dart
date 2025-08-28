import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HavingTroubleView extends StatelessWidget {
  const HavingTroubleView({super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          final lastLoginIssueId = injector<ConfigurationService>()
              .getAnonymousIssueIds()
              .lastOrNull;
          final payload = lastLoginIssueId == null
              ? NewIssuePayload(
                  reportIssueType: ReportIssueType.Bug,
                )
              : DetailIssuePayload(
                  reportIssueType: ReportIssueType.Bug,
                  issueID: lastLoginIssueId,
                );
          await Navigator.of(context).pushNamed(
            AppRouter.supportThreadPage,
            arguments: payload,
          );
        },
        child: Text(
          'having_trouble'.tr(),
          style: Theme.of(context).textTheme.ppMori400Grey14.copyWith(
                decoration: TextDecoration.underline,
              ),
        ),
      );
}
