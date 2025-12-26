//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/onboarding/add_address_page.dart';
import 'package:autonomy_flutter/onboarding/debug_overlay.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Introductory onboarding page:
/// "Explore digital art playlists"
///
/// This widget is implemented using [OnboardingShell] to match the Figma screen:
/// FF1 Art Computer → Onboarding B 4.

class IntroducePagePayload {
  IntroducePagePayload({
    required this.deeplink,
  });

  final String? deeplink;
}

class IntroducePage extends StatelessWidget {
  const IntroducePage({
    required this.payload,
    super.key,
  });

  final IntroducePagePayload payload;

  /// Callback triggered when the user taps the "Next" button.

  @override
  Widget build(BuildContext context) {
    return DebugOverlay(
      imagePath: 'assets/images/screenshots/onboarding_introduce_page.png',
      child: Scaffold(
        backgroundColor: PrimitivesTokens.colorsDarkGrey,
        appBar: const SetupAppBar(
          withDivider: false,
          hasBackButton: false,
        ),
        body: OnboardingShell(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore digital art playlists',
                style: AppTypography.h2(context).white,
              ),
              SizedBox(height: LayoutConstants.space5),
              Text(
                'Browse curated playlists and channels from Feral File and '
                'invited collaborators—right on your phone. You don’t need '
                'any hardware to start exploring.',
                style: AppTypography.body(context).white,
              ),
            ],
          ),
          primaryButton: Row(
            children: [
              Text(
                'Next',
                style: AppTypography.body(context).black,
              ),
              SizedBox(width: LayoutConstants.space2),
              SvgPicture.asset(
                'assets/images/Left.svg',
                colorFilter: const ColorFilter.mode(
                  PrimitivesTokens.colorsBlack,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          onPrimaryPressed: () => onNext(context),
        ),
      ),
    );
  }

  void onNext(BuildContext context) {
    Navigator.of(context).pushNamed(
      AppRouter.onboardingAddAddressPage,
      arguments: OnboardingAddAddressPagePayload(
        deeplink: payload.deeplink,
      ),
    );
  }
}
