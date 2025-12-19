//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/start_setup_ff1_page.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/completer_ext.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
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
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: Column(
        children: [
          OnboardingShell(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add FF1 to your screens',
                  style: theme.textTheme.h3,
                ),
                const SizedBox(height: 20),
                Text(
                  "When you're ready to see these playlists on a wall, plug "
                  'FF1 into any HDMI display and pair it with the app. Press '
                  'Play and your screen becomes a surface for digital and '
                  'computational art.',
                  style: AppTypography.body(context).white,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => onLearnMore(context),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Learn more about the FF1 Art Computer',
                    style: AppTypography.body(context).grey.underline,
                  ),
                ),
              ],
            ),
            primaryButton: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/FF1.svg',
                  colorFilter: const ColorFilter.mode(
                    PrimitivesTokens.colorsBlack,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'Continue setup',
                  style: theme.textTheme.body.copyWith(
                    color: PrimitivesTokens.colorsBlack,
                  ),
                ),
              ],
            ),
            onPrimaryPressed: () => onSetupFf1(context),
            secondaryButton: Row(
              children: [
                Text(
                  'Finish',
                  style: theme.textTheme.body.copyWith(
                    color: PrimitivesTokens.colorsLightBlue,
                  ),
                ),
              ],
            ),
            onSecondaryPressed: () => onFinish(context),
          ),
        ],
      ),
    );
  }

  void onSetupFf1(BuildContext context) {
    startHandleDeeplinkCompleter.safeComplete(true);
    final configService = injector<ConfigurationService>();
    final navigationService = injector<NavigationService>();
    unawaited(configService.setDoneOnboarding(true));
    unawaited(
      navigationService.navigateTo(
        AppRouter.startSetupFF1Page,
        arguments: BluetoothDevicePortalPagePayload(deeplink: null),
      ),
    );
  }

  void onFinish(BuildContext context) {
    startHandleDeeplinkCompleter.safeComplete(true);
    final configService = injector<ConfigurationService>();
    final navigationService = injector<NavigationService>();
    unawaited(configService.setDoneOnboarding(true));
    unawaited(navigationService.replaceAllAndPushNamed(AppRouter.homePage));
  }

  void onLearnMore(BuildContext context) {
    final url = injector<RemoteConfigService>().getConfig<String>(
      ConfigGroup.ff1Config,
      ConfigKey.ff1LearnMoreUrl,
      'https://feralfile.com/install',
    );
    final uri = Uri.parse(url);
    injector<NavigationService>().openUrl(uri);
  }
}
