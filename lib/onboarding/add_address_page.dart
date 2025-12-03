//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

/// Onboarding page 2:
/// "See the art you already own" (Add Address)
///
/// Matches Figma: FF1 Art Computer → Onboarding B 8.
class OnboardingAddAddressPage extends StatelessWidget {
  const OnboardingAddAddressPage({
    super.key,
    required this.onAddAddress,
    required this.onNext,
  });

  /// Triggered when the user taps the "Add Address" secondary button.
  final VoidCallback onAddAddress;

  /// Triggered when the user taps the "Next" primary button.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OnboardingShell(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'See the art you already own',
            style: theme.textTheme.ppMori700White18,
          ),
          const SizedBox(height: 20),
          Text(
            'Add your Ethereum and Tezos addresses to pull in the works you '
            'collect. Use the app as a clear lens on your digital collection, '
            'even before you connect a device.',
            style: theme.textTheme.ppMori400White12,
          ),
          const SizedBox(height: 24),
          _MockAddressList(theme: theme),
        ],
      ),
      secondaryLabel: 'Add Address',
      onSecondaryPressed: onAddAddress,
      primaryLabel: 'Next',
      onPrimaryPressed: onNext,
    );
  }
}

class _MockAddressList extends StatelessWidget {
  const _MockAddressList({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Simple visual approximation of the two address rows in Figma B 8.
    return Column(
      children: const [
        _AddressRow(),
        SizedBox(height: 12),
        _AddressRow(),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColor.primaryBlack,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'einstein-rosen.eth',
            style: theme.textTheme.ppMori400White12.copyWith(
              color: AppColor.feralFileMediumGrey,
            ),
          ),
          const Icon(
            Icons.add,
            size: 16,
            color: AppColor.white,
          ),
        ],
      ),
    );
  }
}
