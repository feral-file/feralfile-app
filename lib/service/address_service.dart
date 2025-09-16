//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/services/address_service.dart'
    as nft;
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/wallet_storage_ext.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sentry/sentry.dart';

class AddressService {
  AddressService(this._cloudObject, this._nftCollectionAddressService);

  final CloudManager _cloudObject;
  final nft.NftAddressService _nftCollectionAddressService;

  Future<bool> registerReferralCode({required String referralCode}) async {
    try {
      await injector<AuthService>()
          .registerReferralCode(referralCode: referralCode);
      return true;
    } catch (e) {
      log.info('Failed to register referral code: $e');
      unawaited(Sentry.captureException(e));
      rethrow;
    }
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
    final addresses = _cloudObject.addressObject.getAllAddresses();
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

  Future<WalletAddress> insertAddress(
    WalletAddress address, {
    bool checkAddressDuplicated = true,
  }) async {
    log.info('Insert address: ${address.address}');
    var checkSumAddress = address.address;
    final cryptoType = address.cryptoType;
    if (cryptoType == CryptoType.ETH || cryptoType == CryptoType.USDC) {
      checkSumAddress = await address.getETHEip55Address();
    }
    log.info('Check sum address: $checkSumAddress');
    if (checkAddressDuplicated) {
      final walletAddress = _cloudObject.addressObject.getAllAddresses();
      if (walletAddress.any((element) => element.address == checkSumAddress)) {
        log.info('Address already exists: $checkSumAddress');
        throw LinkAddressException(message: 'already_imported_address'.tr());
      }
    }
    final newAddress = address.copyWith(address: checkSumAddress);
    await _cloudObject.addressObject.insertAddresses([newAddress]);
    await _nftCollectionAddressService.addAddresses([newAddress.address]);
    await injector<UserDp1PlaylistService>()
        .insertAddressesToPlaylist([newAddress.address]);
    log.info('Inserted address: ${newAddress.address}');
    return newAddress;
  }

  Future<void> insertAddresses(List<WalletAddress> addresses) async {
    await Future.wait(addresses.map(insertAddress));
  }

  Future<void> deleteAddress(WalletAddress address) async {
    await _cloudObject.addressObject.deleteAddress(address);
    await _nftCollectionAddressService.deleteAddresses([address.address]);
    await injector<UserDp1PlaylistService>()
        .removeAddressesFromPlaylist([address.address]);
    log.info('Deleted address: ${address.address}');
  }

  Future<void> setHiddenStatus({
    required List<String> addresses,
    required bool isHidden,
  }) async {
    await Future.wait(
      addresses.map(
        (e) => _cloudObject.addressObject.setAddressIsHidden(e, isHidden),
      ),
    );
    await _nftCollectionAddressService.setIsHiddenAddresses(
      addresses,
      isHidden,
    );
    if (isHidden) {
      // remove from playlist
      await injector<UserDp1PlaylistService>()
          .removeAddressesFromPlaylist(addresses);
    } else {
      // add to playlist
      await injector<UserDp1PlaylistService>()
          .insertAddressesToPlaylist(addresses);
    }
  }

  Future<WalletAddress> nameAddress(WalletAddress address, String name) async {
    final newAddress = address.copyWith(name: name);
    await _cloudObject.addressObject.updateAddresses([newAddress]);
    return newAddress;
  }
}
