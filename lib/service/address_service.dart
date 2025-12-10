//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/wallet_storage_ext.dart';

class AddressService {
  AddressService(this._appDataManager);

  final AppDataManager _appDataManager;

  List<String> getAllAddresses({CryptoType? chain, bool? isHidden}) {
    return getAllWalletAddresses(chain: chain, isHidden: isHidden)
        .map((e) => e.address)
        .toList();
  }

  List<WalletAddress> getAllWalletAddresses({
    CryptoType? chain,
    bool? isHidden,
  }) {
    final addresses = _appDataManager.addressStorageService.getAllAddresses();
    if (chain != null) {
      addresses.removeWhere((element) => element.cryptoType == chain);
    }
    if (isHidden != null) {
      addresses.removeWhere((element) => element.isHidden != isHidden);
    }
    // sort by created time
    addresses.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return addresses;
  }

  WalletAddress? getWalletAddress(String address) {
    return _appDataManager.addressStorageService.getWalletAddress(address);
  }

  Future<WalletAddress> insertAddress(
    WalletAddress address, {
    bool checkAddressDuplicated = true,
    bool refreshPlaylist = true,
  }) async {
    log.info('Insert address: ${address.address}');
    var checkSumAddress = address.address;
    final cryptoType = address.cryptoType;
    if (cryptoType == CryptoType.ETH || cryptoType == CryptoType.USDC) {
      checkSumAddress = await address.getETHEip55Address();
    }
    log.info('Check sum address: $checkSumAddress');
    if (checkAddressDuplicated) {
      final walletAddress =
          _appDataManager.addressStorageService.getAllAddresses();
      if (walletAddress.any((element) => element.address == checkSumAddress)) {
        log.info('Address already exists: $checkSumAddress');
        throw AddAddressException(type: AddAddressExceptionType.alreadyAdded);
      }
    }
    final newAddress = address.copyWith(address: checkSumAddress);
    await _appDataManager.addressStorageService.insertAddresses([newAddress]);
    if (refreshPlaylist) {
      injector<UserAllOwnCollectionBloc>().add(ReindexAddresses(
        addresses: [newAddress.address],
      ));
    }
    await _onAddressUpdate();
    log.info('Inserted address: ${newAddress.address}');
    return newAddress;
  }

  Future<void> insertAddresses(List<WalletAddress> addresses) async {
    await Future.wait(addresses.map(insertAddress));
  }

  Future<void> deleteAddress(WalletAddress address) async {
    await _appDataManager.addressStorageService.deleteAddress(address);
    await _onAddressUpdate();
    log.info('Deleted address: ${address.address}');
  }

  Future<void> setHiddenStatus({
    required List<String> addresses,
    required bool isHidden,
  }) async {
    await Future.wait(
      addresses.map(
        (e) => _appDataManager.addressStorageService
            .setAddressIsHidden(e, isHidden),
      ),
    );
    _onAddressUpdate();
  }

  Future<WalletAddress> nameAddress(WalletAddress address, String name) async {
    final newAddress = address.copyWith(name: name);
    await _appDataManager.addressStorageService.updateAddresses([newAddress]);
    await _onAddressUpdate();
    return newAddress;
  }

  FutureOr<void> _onAddressUpdate() async {
    injector<PlaylistsBloc>(instanceName: PlaylistsBlocInstance.my.instanceName)
        .add(RefreshPlaylistsEvent());
  }
}
