//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onBack: () => Navigator.of(context).pop()),
              const SizedBox(height: 32),
              _HeroIllustration(),
              const SizedBox(height: 40),
              _BodyCopy(theme: theme),
              const Spacer(),
              _StartButton(
                onPressed: () {
                  // TODO(feralfile): Wire up navigation into FF1 device setup flow.
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColor.white,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Setup FF1',
              style: theme.textTheme.ppMori400White16,
            ),
          ),
        ],
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
          'assets/images/FF1.svg',
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
      padding: const EdgeInsets.symmetric(vertical: 11.5),
      color: AppColor.white,
      onTap: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Start FF1 Setup',
          ),
        ],
      ),
    );
  }
}
