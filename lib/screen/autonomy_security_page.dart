//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:io';

import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AutonomySecurityPage extends StatelessWidget {
  const AutonomySecurityPage({super.key});

  String get securityContent {
    if (Platform.isIOS) {
      return 'security_content_ios'.tr();
    } else {
      return 'security_content_else'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: getCloseAppBar(
        context,
        title: 'autonomy_security'.tr(),
        onClose: () => Navigator.of(context).pop(),
      ),
      body: Container(
        margin: ResponsiveLayout.pageHorizontalEdgeInsets,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              addTitleSpace(),
              Text(securityContent, style: theme.textTheme.ppMori400Black14),
            ],
          ),
        ),
      ),
    );
  }
}
