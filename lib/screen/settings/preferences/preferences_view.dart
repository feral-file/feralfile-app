//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/github_doc.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_bloc.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_state.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/au_toggle.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PreferenceView extends StatelessWidget {
  const PreferenceView({super.key});

  @override
  Widget build(BuildContext context) {
    context.read<PreferencesBloc>().add(PreferenceInfoEvent());
    final theme = Theme.of(context);
    return BlocBuilder<PreferencesBloc, PreferenceState>(
        builder: (context, state) {
      final padding =
          ResponsiveLayout.pageEdgeInsets.copyWith(top: 0, bottom: 0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: padding,
            child: _preferenceItemWithBuilder(
              context,
              'analytics'.tr(),
              description: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'contribute_anonymize'.tr(),
                    style: theme.textTheme.ppMori400Black14,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                      child: Text(
                        'learn_anonymize'.tr(),
                        textAlign: TextAlign.left,
                        style: ResponsiveLayout.isMobile
                            ? theme.textTheme.ppMori400Black14.copyWith(
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.solid,
                                decorationColor: Colors.black,
                                decorationThickness: 1.1,
                              )
                            : theme.textTheme.linkStyle16,
                      ),
                      onTap: () => unawaited(Navigator.of(context).pushNamed(
                            AppRouter.githubDocPage,
                            arguments: GithubDocPayload(
                              title: 'how_protect_data'.tr(),
                              prefix: GithubDocPage.ffDocsAgreementsPrefix,
                              document: '/ff-app-data-usage',
                              fileNameAsLanguage: true,
                            ),
                          ))),
                ],
              ),
              isEnabled: state.isAnalyticEnabled,
              onChanged: (value) {
                final newState = state.copyWith(isAnalyticEnabled: value);
                context
                    .read<PreferencesBloc>()
                    .add(PreferenceUpdateEvent(newState));
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _preferenceItemWithBuilder(BuildContext context, String title,
      {bool isEnabled = false,
      WidgetBuilder? description,
      ValueChanged<bool>? onChanged}) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: theme.textTheme.ppMori400Black16),
            AuToggle(value: isEnabled, onToggle: onChanged),
          ],
        ),
        const SizedBox(height: 7),
        if (description != null) description(context),
      ],
    );
  }
}
