//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Start FF1 setup page:
/// "Welcome to FF1" → "Start FF1 Setup".
///
/// Matches Figma: FF1 Art Computer → FF1 Setup 01.
class StartSetupFf1Page extends StatelessWidget {
  const StartSetupFf1Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: getBackAppBar(
        context,
        onBack: () {
          Navigator.of(context).pop();
        },
        title: 'Setup FF1',
        isWhite: false,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // const SizedBox(height: 49),
                // const SizedBox(height: 54),
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
                onPressed: () {
                  // TODO(feralfile): Wire up navigation into FF1 device setup flow.
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
          fit: BoxFit.contain,
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
          style: theme.textTheme.ppMori700White18,
        ),
        const SizedBox(height: 20),
        Text(
          'Thanks for being here. You’re among the first people to bring FF1 '
          'into your space and explore new ways to live with digital art.\n\n'
          'FF1 is designed to make displaying digital art simple, reliable, '
          'and part of your everyday life. As an early adopter, your '
          'experience will help us understand how FF1 fits into real spaces '
          'and routines—and where we should take it next.',
          style: theme.textTheme.ppMori400White12,
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomPrimaryButton(
      padding: const EdgeInsets.only(top: 13, bottom: 10),
      color: AppColor.white,
      onTap: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Start FF1 Setup',
            style: Theme.of(context).textTheme.ppMori400Black14,
          ),
        ],
      ),
    );
  }
}
