//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/onboarding/debug_overlay.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Introductory onboarding page:
/// "Explore digital art playlists"
///
/// This widget is implemented using [OnboardingShell] to match the Figma screen:
/// FF1 Art Computer → Onboarding B 4.
class IntroducePage extends StatelessWidget {
  const IntroducePage({
    super.key,
  });

  /// Callback triggered when the user taps the "Next" button.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DebugOverlay(
      imagePath: 'assets/images/screenshots/onboarding_introduce_page.png',
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        // appBar: getDarkEmptyAppBar(AppColor.auGreyBackground),
        body: Column(
          children: [
            SizedBox(height: 46.3),
            OnboardingShell(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore digital art playlists',
                    style: theme.textTheme.ppMori700White18,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Browse curated playlists and channels from Feral File and '
                    'invited collaborators—right on your phone. You don’t need '
                    'any hardware to start exploring.',
                    style: theme.textTheme.ppMori400White12,
                  ),
                ],
              ),
              primaryButton: Row(
                children: [
                  Text('Next', style: theme.textTheme.ppMori400Black14),
                  const SizedBox(width: 7),
                  SvgPicture.asset('assets/images/Left.svg'),
                ],
              ),
              onPrimaryPressed: () => onNext(context),
              secondaryButton: null,
              onSecondaryPressed: null,
            ),
          ],
        ),
      ),
    );
  }

  void onNext(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.onboardingAddAddressPage);
  }
}
