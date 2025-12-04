//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

/// Onboarding page 2:
/// "See the art you already own" (Add Address)
///
/// Matches Figma: FF1 Art Computer → Onboarding B 8.
class OnboardingAddAddressPage extends StatefulWidget {
  const OnboardingAddAddressPage({
    super.key,
  });

  @override
  State<OnboardingAddAddressPage> createState() =>
      _OnboardingAddAddressPageState();
}

class _OnboardingAddAddressPageState extends State<OnboardingAddAddressPage>
    with RouteAware {
  late final AccountsBloc _accountsBloc;

  @override
  void initState() {
    super.initState();
    _accountsBloc = injector<AccountsBloc>();
    _accountsBloc.add(FetchAllAddressesEvent());
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _accountsBloc.add(FetchAllAddressesEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: BlocProvider.value(
        value: _accountsBloc,
        child: Column(
          children: [
            SizedBox(height: 46.3),
            OnboardingShell(
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
                  _AddressList(theme: theme),
                ],
              ),
              secondaryButton: Row(
                children: [
                  SvgPicture.asset('assets/images/Add_blue.svg'),
                  const SizedBox(width: 7),
                  Text('Add Address',
                      style: theme.textTheme.ppMori400Black14
                          .copyWith(color: AppColor.feralFileLightBlue)),
                ],
              ),
              onSecondaryPressed: () => onAddAddress(context),
              primaryButton: Row(
                children: [
                  Text('Next', style: theme.textTheme.ppMori400Black14),
                  const SizedBox(width: 7),
                  SvgPicture.asset('assets/images/Left.svg'),
                ],
              ),
              onPrimaryPressed: () => onNext(context),
            ),
          ],
        ),
      ),
    );
  }

  void onAddAddress(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.onboardingAddAddressInputPage);
  }

  void onNext(BuildContext context) {
    Navigator.of(context).pushNamed(AppRouter.onboardingSetupFf1Page);
  }
}

class _AddressList extends StatelessWidget {
  const _AddressList({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountsBloc, AccountsState>(
      builder: (context, state) {
        final addresses = state.addresses;
        if (addresses == null) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }
        if (addresses.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            for (final address in addresses) ...[
              _AddressRow(address: address),
              if (address != addresses.last) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final WalletAddress address;

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
          Expanded(
            child: Text(
              address.name,
              style: theme.textTheme.ppMori400White12.copyWith(
                color: AppColor.feralFileMediumGrey,
              ),
              overflow: TextOverflow.ellipsis,
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
