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
import 'package:autonomy_flutter/nft_collection/services/drift_bootstrap_service.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/wallet_storage_ext.dart';

class AddressService {
  AddressService(this._appDataManager);

  final AppDataManager _appDataManager;

  Future<List<String>> getAllAddressesFromDrift(
      {CryptoType? chain, bool? isHidden}) async {
    return (await injector<DriftDatabaseService>().getAddressPlaylistRows())
        .map((p) => p.ownerAddress)
        .nonNulls
        .toList();
  }

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
    try {
      log.info('Insert address: ${address.address}');
      var checkSumAddress = address.address;
      final cryptoType = address.cryptoType;
      if (cryptoType == CryptoType.ETH || cryptoType == CryptoType.USDC) {
        checkSumAddress = await address.getETHEip55Address();
      }
      log.info('Check sum address: $checkSumAddress');
      if (checkAddressDuplicated) {
        final driftAddress = await getAllAddressesFromDrift();
        if (driftAddress.contains(checkSumAddress)) {
          log.info('Address already exists: $checkSumAddress');
          throw AddAddressException(type: AddAddressExceptionType.alreadyAdded);
        }
      }
      final newAddress = address.copyWith(address: checkSumAddress);
      // await _appDataManager.addressStorageService.insertAddresses([newAddress]);
      final playlist = DP1CallExtension.fromOwner(
        owners: [newAddress.address],
        title: newAddress.name,
      );
      final playlistRef = PlaylistReference(
        playlist: playlist,
        url: '',
        type: PlaylistReferenceType.address,
      );
      await injector<DriftDatabaseService>().ingestPlaylist(
        playlistRef,
        DriftBootstrapService.myCollectionChannelId,
      );
      if (refreshPlaylist) {
        final manager = injector<UserAllOwnCollectionBlocManager>();
        final bloc = manager.getOrCreateBloc([newAddress.address]);
        bloc.add(Reindex());
      }
      log.info('Inserted address: ${newAddress.address}');
      return newAddress;
    } catch (e) {
      log.info('Error inserting address: $e');
      throw e;
    }
  }

  Future<void> deleteAddressFromDrift(String address) async {
    await injector<DriftDatabaseService>().deletePlaylistById(address);
    _appDataManager.addressStorageService.deleteAddresses([address]);
    await injector<UserDp1PlaylistService>().clearAddressIndexingInfo(
      addresses: [address],
    );
    await injector<UserDp1PlaylistService>().clearAddressLastFetchTokenTime(
      addresses: [address],
    );
    await injector<UserDp1PlaylistService>().removeLastUpdateChangeAnchor(
      addresses: [address],
    );
    injector<PlaylistDetailsBlocManager>().releaseBloc(address, force: true);
  }

  /// Check if tokens have been fetched for a list of addresses.
  ///
  /// Returns true if all addresses have been fetched (have a non-null
  /// last fetch token time), false otherwise.
  bool areAddressesFetched(List<String> addresses) {
    if (addresses.isEmpty) return true;

    final fetchTimes = injector<UserDp1PlaylistService>()
        .getAddressOldestLastFetchTokenTime(addresses: addresses);

    // Check if all addresses have been fetched (non-null DateTime)
    return addresses.every((address) => fetchTimes[address] != null);
  }
}
