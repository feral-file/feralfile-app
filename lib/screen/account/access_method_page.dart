//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: unused_field

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/au_text_field.dart';
import 'package:autonomy_flutter/view/au_toggle.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AccessMethodPage extends StatefulWidget {
  const AccessMethodPage({super.key});

  @override
  State<AccessMethodPage> createState() => _AccessMethodPageState();
}

class _AccessMethodPageState extends State<AccessMethodPage> {
  var _redrawObject = Object();
  final padding = ResponsiveLayout.pageEdgeInsets.copyWith(top: 0, bottom: 0);
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getBackAppBar(
          context,
          title: 'Test page',
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _linkDebugWidget(context),
                const SizedBox(height: 16),
                AuTextField(title: 'url', controller: _controller),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

  Widget _addWalletItem({
    required BuildContext context,
    required String title,
    required dynamic Function()? onTap,
    String? content,
    bool forward = true,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.ppMori400Black16,
                  ),
                  const Spacer(),
                  if (forward)
                    SvgPicture.asset('assets/images/iconForward.svg')
                  else
                    const SizedBox(),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Text(
              content ?? '',
              style: theme.textTheme.ppMori400Black14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkDebugWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: padding,
          child: _addWalletItem(
            context: context,
            title: 'test_artwork'.tr(),
            onTap: () async => Navigator.of(context).pushNamed(
              AppRouter.testArtwork,
            ),
          ),
        ),
        addDivider(height: 48),
        Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'show_token_debug_log'.tr(),
                style: theme.textTheme.headlineMedium,
              ),
              AuToggle(
                value: injector<ConfigurationService>().showTokenDebugInfo(),
                onToggle: (isEnabled) async {
                  await injector<ConfigurationService>()
                      .setShowTokenDebugInfo(isEnabled);
                  setState(() {
                    _redrawObject = Object();
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
