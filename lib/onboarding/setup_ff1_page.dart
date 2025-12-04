//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Onboarding page 3:
/// "Add FF1 to your screens" (Setup FF1)
///
/// Matches Figma: FF1 Art Computer → Onboarding B 6.
class OnboardingSetupFf1Page extends StatelessWidget {
  const OnboardingSetupFf1Page({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: Column(
        children: [
          SizedBox(height: 46.3),
          OnboardingShell(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add FF1 to your screens',
                  style: theme.textTheme.ppMori700White18,
                ),
                const SizedBox(height: 20),
                Text(
                  'When you’re ready to see these playlists on a wall, plug FF1 into '
                  'any HDMI display and pair it with the app. Press Play and your '
                  'screen becomes a surface for digital and computational art.',
                  style: theme.textTheme.ppMori400White12,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => onLearnMore(context),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Learn more about the FF1 Art Computer',
                    style: theme.textTheme.ppMori400White12.copyWith(
                      color: AppColor.feralFileMediumGrey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            secondaryButton: Row(
              children: [
                SvgPicture.asset('assets/images/FF1.svg'),
                const SizedBox(width: 7),
                Text('Setup FF1',
                    style: theme.textTheme.ppMori400Black14
                        .copyWith(color: AppColor.feralFileLightBlue)),
              ],
            ),
            onSecondaryPressed: () => onSetupFf1(context),
            primaryButton: Row(
              children: [
                Text('Finish', style: theme.textTheme.ppMori400Black14),
              ],
            ),
            onPrimaryPressed: () => onFinish(context),
          ),
        ],
      ),
    );
  }

  void onSetupFf1(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.onboardingStartSetupFf1Page);
  }

  void onFinish(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.homePage);
  }

  void onLearnMore(BuildContext context) {
    final uri = Uri.parse('https://feralfile.com/ff1');
    injector<NavigationService>().openUrl(uri);
  }
}
