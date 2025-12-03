//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
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
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.showBottomProgress = true,
    this.primaryLeading,
    this.secondaryLeading,
  });

  /// Main content of the onboarding step (usually title + body + illustration).
  final Widget content;

  /// Label for the primary (right) button – e.g., "Next", "Finish".
  final String primaryLabel;

  /// Callback when the primary button is pressed.
  final VoidCallback onPrimaryPressed;

  /// Optional label for the secondary (left) button – e.g., "Add Address", "Setup FF1".
  final String? secondaryLabel;

  /// Optional callback for the secondary button.
  final VoidCallback? onSecondaryPressed;

  /// Optional leading widget/icon for the primary button.
  final Widget? primaryLeading;

  /// Optional leading widget/icon for the secondary button.
  final Widget? secondaryLeading;

  /// Whether to show the white bottom progress line.
  final bool showBottomProgress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 287.94),
          Container(
              constraints: const BoxConstraints(
                minHeight: 255.06,
              ),
              child: content),
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
        if (secondaryLabel != null && onSecondaryPressed != null) ...[
          _OnboardingOutlinedButton(
            label: secondaryLabel!,
            leading: secondaryLeading,
            onPressed: onSecondaryPressed!,
          ),
          const SizedBox(width: 12),
        ],
        _OnboardingFilledButton(
          label: primaryLabel,
          leading: primaryLeading,
          onPressed: onPrimaryPressed,
        ),
      ],
    );
  }
}

class _OnboardingFilledButton extends StatelessWidget {
  const _OnboardingFilledButton({
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: AppColor.feralFileLightBlue,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        shape: const StadiumBorder(),
        minimumSize: const Size(146, 43),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColor.primaryBlack,
                  fontSize: 14,
                ),
          ),
          if (leading == null) ...[
            const SizedBox(width: 7),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColor.primaryBlack,
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingOutlinedButton extends StatelessWidget {
  const _OnboardingOutlinedButton({
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        shape: const StadiumBorder(),
        minimumSize: const Size(146, 43),
        side: const BorderSide(
          color: AppColor.feralFileLightBlue,
          width: 1,
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColor.feralFileLightBlue,
                  fontSize: 14,
                ),
          ),
        ],
      ),
    );
  }
}
