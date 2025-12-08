//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/material.dart';

/// Generic shell widget for new onboarding screens.
///
/// This widget encapsulates the common layout from the FF1 Art Computer
/// onboarding designs:
/// - Dark background
/// - Centered content block (title, body, custom widgets, etc.)
/// - Two action buttons at the bottom
/// - Optional bottom progress indicator line
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.content,
    this.primaryButton,
    this.onPrimaryPressed,
    this.secondaryButton,
    this.onSecondaryPressed,
    this.showBottomProgress = true,
  });

  /// Main content of the onboarding step (usually title + body + illustration).
  final Widget content;

  /// Label for the primary (right) button – e.g., "Next", "Finish".
  final Widget? primaryButton;

  /// Callback when the primary button is pressed.
  final VoidCallback? onPrimaryPressed;

  /// Optional label for the secondary (left) button – e.g., "Add Address", "Setup FF1".
  final Widget? secondaryButton;

  /// Optional callback for the secondary button.
  final VoidCallback? onSecondaryPressed;

  /// Whether to show the white bottom progress line.
  final bool showBottomProgress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 206.94,
          ),
          Container(
              constraints: const BoxConstraints(
                minHeight: 245.06,
              ),
              child: content),
          const SizedBox(height: 10),
          _buildButtonsRow(context),
        ],
      ),
    );
  }

  Widget _buildButtonsRow(BuildContext context) {
    // Keep layout close to Figma: two pill-shaped buttons,
    // left = secondary (outline), right = primary (filled).
    return Row(
      children: [
        Expanded(
          child: (secondaryButton != null && onSecondaryPressed != null)
              ? CustomPrimaryButton(
                  padding: const EdgeInsets.symmetric(vertical: 11.5),
                  onTap: onSecondaryPressed,
                  child: secondaryButton!,
                  borderColor: AppColor.feralFileLightBlue,
                  color: Colors.transparent,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: (primaryButton != null && onPrimaryPressed != null)
              ? CustomPrimaryButton(
                  padding: const EdgeInsets.symmetric(vertical: 11.5),
                  onTap: onPrimaryPressed,
                  child: primaryButton!,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
