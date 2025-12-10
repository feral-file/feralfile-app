//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/onboarding/add_address_page.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Start FF1 setup page:
/// "Welcome to FF1" → "Start FF1 Setup".
///
/// Matches Figma: FF1 Art Computer → FF1 Setup 01.

class BluetoothDevicePortalPagePayload {
  BluetoothDevicePortalPagePayload({
    required this.deeplink,
    this.isFromAppLink = false,
  });

  final String? deeplink;
  final bool isFromAppLink;
}

class StartSetupFf1Page extends StatefulWidget {
  const StartSetupFf1Page({required this.payload, super.key});

  final BluetoothDevicePortalPagePayload payload;

  @override
  State<StartSetupFf1Page> createState() => _StartSetupFf1PageState();
}

class _StartSetupFf1PageState extends State<StartSetupFf1Page> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: const CustomAppBar(
        backTitle: 'Setup FF1',
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 64.48),
                _HeroIllustration(),
                const SizedBox(height: 64.48),
                _BodyCopy(theme: Theme.of(context)),
                const Spacer(),
                const SizedBox(height: 32),
                const SizedBox(height: 16),
              ],
            ),
            Positioned(
              bottom: 83,
              left: 0,
              right: 0,
              child: _StartButton(
                text: widget.payload.isFromAppLink
                    ? 'Continue'
                    : 'Start FF1 Setup',
                onPressed: () async {
                  String deeplink;
                  if (widget.payload.deeplink != null) {
                    deeplink = widget.payload.deeplink!;
                  } else {
                    final result =
                        await injector<NavigationService>().navigateTo(
                      AppRouter.scanQRPage,
                      arguments: const ScanQRPagePayload(
                        scannerItem: ScannerItem.GLOBAL,
                        isFromOnboarding: true,
                      ),
                    );
                    if (result != null) {
                      deeplink = result as String;
                    } else {
                      return;
                    }
                  }

                  if (widget.payload.isFromAppLink &&
                      !injector<ConfigurationService>().isDoneOnboarding()) {
                    await injector<NavigationService>().navigateTo(
                      AppRouter.onboardingIntroducePage,
                      arguments: OnboardingAddAddressPagePayload(
                        deeplink: widget.payload.deeplink,
                      ),
                    );
                  } else {
                    await injector<NavigationService>().navigateTo(
                      AppRouter.handleBluetoothDeviceScanDeeplinkScreen,
                      arguments: HandleBluetoothDeviceScanDeeplinkScreenPayload(
                        deeplink: deeplink,
                        onFinish: () async {
                          await injector<NavigationService>().navigateTo(
                            AppRouter.scanWifiNetworkPage,
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 247,
        width: 305,
        child: SvgPicture.asset(
          'assets/images/ff1_case.svg',
        ),
      ),
    );
  }
}

class _BodyCopy extends StatelessWidget {
  const _BodyCopy({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to FF1',
          style: theme.textTheme.h3,
        ),
        const SizedBox(height: 20),
        Text(
          'Thanks for being here. You’re among the first people to bring FF1 '
          'into your space and explore new ways to live with digital art.\n\n'
          'FF1 is designed to make displaying digital art simple, reliable, '
          'and part of your everyday life. As an early adopter, your '
          'experience will help us understand how FF1 fits into real spaces '
          'and routines—and where we should take it next.',
          style: theme.textTheme.small,
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.onPressed,
    required this.text,
  });

  final VoidCallback onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomPrimaryButton(
      padding: const EdgeInsets.only(top: 13, bottom: 10),
      color: PrimitivesTokens.colorsLightBlue,
      onTap: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.body.copyWith(
                  color: PrimitivesTokens.colorsBlack,
                ),
          ),
        ],
      ),
    );
  }
}
