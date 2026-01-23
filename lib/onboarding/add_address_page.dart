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
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/onboarding/add_address_input_page.dart';
import 'package:autonomy_flutter/onboarding/onboarding_shell.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
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
  late final PlaylistsBloc _playlistsBloc;
  late final AddressService _addressService;
  late final DriftDatabaseService _driftDatabaseService;

  @override
  void initState() {
    super.initState();
    _playlistsBloc = injector<PlaylistsBloc>(
      instanceName: PlaylistsBlocInstance.my.instanceName,
    );
    _addressService = injector<AddressService>();
    _driftDatabaseService = injector<DriftDatabaseService>();
    _playlistsBloc.add(LoadPlaylistsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: BlocProvider.value(
        value: _playlistsBloc,
        child: OnboardingShell(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'See the art you already own',
                style: AppTypography.h2(context).white,
              ),
              SizedBox(height: LayoutConstants.space5),
              Text(
                'Add your Ethereum and Tezos addresses to pull in the works you '
                'collect. Use the app as a clear lens on your digital collection, '
                'even before you connect a device.',
                style: AppTypography.body(context).white,
              ),
              SizedBox(height: LayoutConstants.space5),
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
              SizedBox(width: LayoutConstants.space2),
              Text(
                'Add Address',
                style: AppTypography.body(context).black,
              ),
            ],
          ),
          onPrimaryPressed: () => onAddAddress(context),
          secondaryButton: BlocBuilder<PlaylistsBloc, PlaylistsState>(
            builder: (context, state) {
              final addressEntries = _getAddressEntries(state);
              final isEmpty = addressEntries.isEmpty;
              final buttonText = isEmpty ? 'Skip for now' : 'Next';

              return Row(
                children: [
                  Text(
                    buttonText,
                    style: AppTypography.body(context).lightBlue,
                  ),
                  SizedBox(width: LayoutConstants.space2),
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
      ),
    );
  }

  List<_AddressEntry> _getAddressEntries(PlaylistsState state) {
    final entries = <_AddressEntry>[];
    for (final playlistData in state.playlistData) {
      final playlist = playlistData.playlistReference.playlist;
      if (!playlist.isAddressPlaylist) {
        continue;
      }
      final owners = playlist.addressOwners;
      if (owners.isEmpty) {
        continue;
      }
      final ownerAddress = owners.first;
      final walletAddress = _addressService.getWalletAddress(ownerAddress) ??
          WalletAddress(
            address: ownerAddress,
            createdAt: playlist.created,
            name: playlist.title,
          );
      entries.add(
        _AddressEntry(
          walletAddress: walletAddress,
          playlistId: playlist.id,
        ),
      );
    }
    return entries;
  }

  void onDelete(_AddressEntry entry) {
    UIHelper.showDeleteAccountConfirmation(entry.walletAddress,
        (address) async {
      final completer = Completer<void>();
      try {
        await _driftDatabaseService.deletePlaylistById(entry.playlistId);
        await _addressService.deleteAddressFromDrift(address.address);
        completer.complete();
      } catch (error) {
        completer.completeError(error);
      }
      await completer.future;
    });
  }

  Future<void> onAddAddress(BuildContext context) async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.onboardingAddAddressInputPage,
      arguments: OnboardingAddAddressInputPagePayload(),
    );
  }

  void onNext(BuildContext context) {
    if (widget.payload.deeplink != null) {
      injector<ConfigurationService>().setDoneOnboarding(true);
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

  final void Function(_AddressEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      builder: (context, state) {
        final addressEntries = _getAddressEntries(context, state);
        if (state.isLoading && addressEntries.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }
        if (addressEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: addressEntries.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                _AddressRow(
                  entry: addressEntries[index],
                  onDelete: onDelete,
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<_AddressEntry> _getAddressEntries(
    BuildContext context,
    PlaylistsState state,
  ) {
    final addressService = injector<AddressService>();
    final entries = <_AddressEntry>[];
    for (final playlistData in state.playlistData) {
      final playlist = playlistData.playlistReference.playlist;
      if (!playlist.isAddressPlaylist) {
        continue;
      }
      final owners = playlist.addressOwners;
      if (owners.isEmpty) {
        continue;
      }
      final ownerAddress = owners.first;
      final walletAddress = addressService.getWalletAddress(ownerAddress) ??
          WalletAddress(
            address: ownerAddress,
            createdAt: playlist.created,
            name: playlist.title,
          );
      entries.add(
        _AddressEntry(
          walletAddress: walletAddress,
          playlistId: playlist.id,
        ),
      );
    }
    return entries;
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.entry, required this.onDelete});

  final _AddressEntry entry;
  final void Function(_AddressEntry) onDelete;
  @override
  Widget build(BuildContext context) {
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
              padding: EdgeInsets.only(
                top: LayoutConstants.space3 - 1,
                bottom: LayoutConstants.space3,
              ),
              child: Text(
                entry.walletAddress.name,
                style: AppTypography.body(context).grey,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onDelete(entry),
            child: Container(
              color: Colors.transparent,
              padding: EdgeInsets.only(
                top: LayoutConstants.space3 - 1,
                bottom: LayoutConstants.space3,
                left: LayoutConstants.space3,
              ),
              child: SvgPicture.asset('assets/images/minus.svg'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressEntry {
  const _AddressEntry({
    required this.walletAddress,
    required this.playlistId,
  });

  final WalletAddress walletAddress;
  final String playlistId;
}
