//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/models/objectbox_entities.dart';
import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry/sentry.dart';

/// Simple manager wrapping ObjectBox operations for Indexer persistence.
class IndexerDataBaseObjectBox implements IndexerDatabaseAbstract {
  IndexerDataBaseObjectBox(this.store) : tokenBox = store.box<TokenObject>();

  final Store store;
  final Box<TokenObject> tokenBox;

  QueryProperty<TokenObject, dynamic> convertSortByToQueryProperty(
      IndexerDatabaseSortBy sortBy) {
    switch (sortBy) {
      case IndexerDatabaseSortBy.updatedAt:
        return TokenObject_.updatedAt;
    }
  }

  /// Insert or update a Token (v2) into ObjectBox as TokenObject.
  @override
  int insertToken(v2.AssetToken token) {
    final tokenObject = TokenObject.fromToken(token);
    final existing = tokenBox
        .query(TokenObject_.uniqueId.equals(tokenObject.uniqueId))
        .build()
        .findFirst();
    if (existing != null) {
      tokenObject.id = existing.id;
    }
    try {
      final tokenId = tokenBox.put(tokenObject);
      return tokenId;
    } catch (e) {
      log.info('Error inserting token: $e');
      Sentry.captureException('Error inserting token: $e');
      rethrow;
    }
  }

  @override
  void insertTokens(List<v2.AssetToken> tokens) {
    for (final token in tokens) {
      insertToken(token);
    }
  }

  /// Get all Tokens owned by a specific owner address.
  @override
  List<v2.AssetToken> getTokensByOwner({
    required String ownerAddress,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  }) {
    final sortByProperty = convertSortByToQueryProperty(sortBy);
    final query = tokenBox
        .query(TokenObject_.currentOwner.equals(ownerAddress))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toToken()).toList();
    } catch (e) {
      log.info('Error getting tokens by owner: $e');
      return [];
    } finally {
      query.close();
    }
  }

  @override
  List<AddressAssetTokens> getGroupAssetTokensByOwnersGroupByAddress(
      {required List<String> owners,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt}) {
    final groupByAddress = <AddressAssetTokens>[];
    log.info('[getGroupAssetTokensByOwnersGroupByAddress] Owners: $owners');
    for (final owner in owners) {
      final assetTokens = getTokensByOwner(ownerAddress: owner, sortBy: sortBy);
      if (assetTokens.isEmpty) {
        log.info(
            '[getGroupAssetTokensByOwnersGroupByAddress] No asset tokens for owner: $owner');
        continue;
      }
      final address = owner;
      final walletAddress =
          injector<AddressService>().getWalletAddress(address);
      if (walletAddress == null) {
        log.info(
            '[getGroupAssetTokensByOwnersGroupByAddress] Wallet address not found: $address');
        continue;
      }

      groupByAddress.add(
        AddressAssetTokens(
          address: walletAddress,
          assetTokens: assetTokens,
        ),
      );
    }
    return groupByAddress;
  }

  /// get tokens by CIDs
  @override
  List<v2.AssetToken> getTokensByCIDs({
    required List<String> cids,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  }) {
    final sortByProperty = convertSortByToQueryProperty(sortBy);
    final query = tokenBox
        .query(TokenObject_.cid.oneOf(cids))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toToken()).toList();
    } catch (e) {
      log.info('Error getting tokens by cids: $e');
      return [];
    } finally {
      query.close();
    }
  }

  @override
  void clearAll() {
    tokenBox.removeAll();
  }

  @override
  List<v2.AssetToken> getTokensByOwners({
    required List<String> owners,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  }) {
    final sortByProperty = convertSortByToQueryProperty(sortBy);
    final query = tokenBox
        .query(TokenObject_.currentOwner.oneOf(owners))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toToken()).toList();
    } catch (e) {
      log.info('Error getting tokens by owners: $e');
      return [];
    } finally {
      query.close();
    }
  }

  @override
  v2.AssetToken? findTokenByCid(String cid) {
    final query = tokenBox.query(TokenObject_.cid.equals(cid)).build();
    try {
      final results = query.find();
      return results.isNotEmpty ? results.first.toToken() : null;
    } catch (e) {
      log.info('Error getting token by cid: $e');
      return null;
    } finally {
      query.close();
    }
  }
}
