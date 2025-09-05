//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/app_theme.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BugBountyPage extends StatelessWidget {
  const BugBountyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Map<String, String> guidelines = {
      'critical'.tr(): 'guidelines_critical'.tr(),
      //"Key leaks or invalid transactions resulting in asset loss: Up to \$5,000",
      'high'.tr(): 'guidelines_high'.tr(),
      // "Crashes or user data loss: \$100 - \$500",
      'medium'.tr(): 'guidelines_medium'.tr(),
      //"Incorrect flows or incompatibility with protocol or dapps: \$50 - \$100",
      'low'.tr(): 'guidelines_low'.tr(),
      // "UI typos, alignment errors: \$10 - \$50",
    };

    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'bug_bounty'.tr(),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Container(
        margin: ResponsiveLayout.pageEdgeInsetsNotBottom,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              addTitleSpace(),
              Text(
                'we_value_feedback'.tr(),
                style: theme.textTheme.ppMori400Black16,
              ),
              const SizedBox(height: 32),
              Text('scope'.tr(), style: theme.textTheme.ppMori700Black24),
              const SizedBox(height: 32),
              RichText(
                  textScaler: MediaQuery.textScalerOf(context),
                  text: TextSpan(
                      style: theme.textTheme.ppMori400Black16,
                      children: <TextSpan>[
                        TextSpan(
                          text: '${'only_accept_new_bug'.tr()} ',
                        ),
                        TextSpan(
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => unawaited(launchUrl(
                                  Uri.parse(KNOWN_BUGS_LINK),
                                  mode: LaunchMode.externalApplication,
                                )),
                          text: 'known_bugs'.tr(),
                          style: ResponsiveLayout.isMobile
                              ? theme.textTheme.linkStyle16.copyWith(
                                  fontWeight: FontWeight.normal,
                                  fontFamily: AppTheme.ppMori)
                              : theme.textTheme.linkStyle16,
                        ),
                        TextSpan(
                          text: ' ${'not_reward_yet'.tr()}',
                        ),
                      ])),
              const SizedBox(height: 32),
              Text('rewards'.tr(), style: theme.textTheme.ppMori700Black24),
              const SizedBox(height: 32),
              Text(
                'reward_ranging'.tr(),
                style: theme.textTheme.ppMori400Black16,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColor.feralFileHighlight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'guidelines'.tr(),
                      style: (ResponsiveLayout.isMobile
                              ? theme.textTheme.ppMori400Black14
                              : theme.textTheme.ppMori400Black16)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...guidelines.keys.map(
                      (e) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            ' •  ',
                            style: theme.textTheme.ppMori400Black14,
                            textAlign: TextAlign.start,
                          ),
                          Expanded(
                            child: RichText(
                              textScaler: MediaQuery.textScalerOf(context),
                              text: TextSpan(
                                style: theme.textTheme.ppMori400Black14,
                                children: <TextSpan>[
                                  TextSpan(
                                    text: e,
                                    style: ResponsiveLayout.isMobile
                                        ? theme.textTheme.ppMori400Black14
                                        : theme.textTheme.ppMori400Black16,
                                  ),
                                  TextSpan(
                                    text: ' – ${guidelines[e]!}',
                                    style: ResponsiveLayout.isMobile
                                        ? theme.textTheme.ppMori400Black14
                                        : theme.textTheme.ppMori400Black16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'rewards_in_xtz_or_eth'.tr(),
                style: theme.textTheme.ppMori400Black16,
              ),
              const SizedBox(height: 32),
              Text('disclosure_policy'.tr(),
                  style: theme.textTheme.ppMori700Black24),
              const SizedBox(height: 32),
              Text('support_publication'.tr(),
                  style: theme.textTheme.ppMori400Black16),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'report_a_bug'.tr(),
                onTap: () => unawaited(Navigator.of(context).pushNamed(
                    AppRouter.supportThreadPage,
                    arguments:
                        NewIssuePayload(reportIssueType: ReportIssueType.Bug))),
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}
