//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/onboarding/add_address_input_page.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

/// Onboarding page 2:
/// "See the art you already own" (Add Address)
///
/// Matches Figma: FF1 Art Computer → Onboarding B 8.

class OnboardingAddAddressPagePayload {
  OnboardingAddAddressPagePayload({
    required this.deeplink,
  });

  final String? deeplink;
}

class OnboardingAddAddressPage extends StatefulWidget {
  const OnboardingAddAddressPage({required this.payload, super.key});

  final OnboardingAddAddressPagePayload payload;

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
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: const CustomAppBar(
        backTitle: 'Back',
      ),
      body: BlocProvider.value(
        value: _accountsBloc,
        child: Column(
          children: [
            OnboardingShell(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'See the art you already own',
                    style: theme.textTheme.h3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Add your Ethereum and Tezos addresses to pull in the works you '
                    'collect. Use the app as a clear lens on your digital collection, '
                    'even before you connect a device.',
                    style: theme.textTheme.small,
                  ),
                  const SizedBox(height: 20),
                  _AddressList(theme: theme, onDelete: onDelete),
                ],
              ),
              primaryButton: Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/Add_blue.svg',
                    colorFilter: const ColorFilter.mode(
                      PrimitivesTokens.colorsBlack,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Add Address',
                    style: theme.textTheme.body.copyWith(
                      color: PrimitivesTokens.colorsBlack,
                    ),
                  ),
                ],
              ),
              onPrimaryPressed: () => onAddAddress(context),
              secondaryButton: BlocBuilder<AccountsBloc, AccountsState>(
                builder: (context, state) {
                  final addresses = state.addresses;
                  final isEmpty = addresses == null || addresses.isEmpty;
                  final buttonText = isEmpty ? 'Skip for now' : 'Next';

                  return Row(
                    children: [
                      Text(
                        buttonText,
                        style: theme.textTheme.body.copyWith(
                          color: PrimitivesTokens.colorsLightBlue,
                        ),
                      ),
                      const SizedBox(width: 7),
                      SvgPicture.asset(
                        'assets/images/Left.svg',
                        colorFilter: const ColorFilter.mode(
                          PrimitivesTokens.colorsLightBlue,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  );
                },
              ),
              onSecondaryPressed: () => onNext(context),
              hintText: 'You can always add addresses later.',
            ),
          ],
        ),
      ),
    );
  }

  void onDelete(WalletAddress address) {
    UIHelper.showDeleteAccountConfirmation(address, (address) async {
      final completer = Completer<void>();
      _accountsBloc.add(DeleteAddressEvent(address, onSuccess: () {
        completer.complete();
      }, onError: (error, stackTrace) {
        completer.completeError(error);
      }));
      await completer.future;
    });
  }

  Future<void> onAddAddress(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.onboardingAddAddressInputPage,
      arguments: OnboardingAddAddressInputPagePayload(),
    );
    if (result != null && result is WalletAddress) {
      _accountsBloc.add(FetchAllAddressesEvent());
    }
  }

  void onNext(BuildContext context) {
    if (widget.payload.deeplink != null) {
      // Skip OnboardingSetupFf1Page and go directly to Bluetooth setup
      injector<NavigationService>().navigateTo(
        AppRouter.handleBluetoothDeviceScanDeeplinkScreen,
        arguments: HandleBluetoothDeviceScanDeeplinkScreenPayload(
          deeplink: widget.payload.deeplink!,
          onFinish: () async {
            await injector<NavigationService>().navigateTo(
              AppRouter.scanWifiNetworkPage,
            );
          },
        ),
      );
    } else {
      Navigator.of(context).pushNamed(AppRouter.onboardingSetupFf1Page);
    }
  }
}

class _AddressList extends StatelessWidget {
  const _AddressList({required this.theme, required this.onDelete});

  final ThemeData theme;

  final void Function(WalletAddress) onDelete;

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

        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                _AddressRow(address: addresses[index], onDelete: onDelete),
              ],
            );
          },
        );
      },
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onDelete});

  final WalletAddress address;
  final void Function(WalletAddress) onDelete;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(
        // top border only
        border: Border(
          top: BorderSide(),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 11, bottom: 12),
              child: Text(
                address.name,
                style: theme.textTheme.small.copyWith(
                  color: PrimitivesTokens.colorsGrey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onDelete(address),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(top: 11, bottom: 12, left: 12),
              child: SvgPicture.asset('assets/images/minus.svg'),
            ),
          ),
        ],
      ),
    );
  }
}
