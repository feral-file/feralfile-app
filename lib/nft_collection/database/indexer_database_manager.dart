//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/nft_collection/models/objectbox_entities.dart';
import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry/sentry.dart';

/// Simple manager wrapping ObjectBox operations for Indexer persistence.
class IndexerDataBaseObjectBox implements IndexerDatabaseAbstract {
  IndexerDataBaseObjectBox(this.store)
      : assetTokenBox = store.box<AssetTokenObject>(),
        assetBox = store.box<AssetObject>(),
        provenanceBox = store.box<ProvenanceObject>();

  final Store store;
  final Box<AssetTokenObject> assetTokenBox;
  final Box<AssetObject> assetBox;
  final Box<ProvenanceObject> provenanceBox;

  QueryProperty<AssetTokenObject, dynamic> convertSortByToQueryProperty(
      IndexerDatabaseSortBy sortBy) {
    switch (sortBy) {
      case IndexerDatabaseSortBy.lastActivityTime:
        return AssetTokenObject_.lastActivityTime;
    }
  }

  /// Insert or update an AssetToken (domain) into ObjectBox as AssetTokenObject.
  /// If the token contains an Asset, it will be stored first and linked via ToOne.
  /// Returns the ObjectBox id of the stored AssetTokenObject.
  @override
  int insertAssetToken(AssetToken assetToken) {
    final tokenObject = AssetTokenObject.fromAssetToken(
      assetToken,
    );

    var assetObject = tokenObject.asset.target;
    if (assetObject != null) {
      final existingAssetObject = assetBox
          .query(AssetObject_.uniqueId.equals(assetObject.uniqueId))
          .build()
          .findFirst();
      if (existingAssetObject != null) {
        assetObject.id = existingAssetObject.id;
      }
    }

    var provenanceObjects = tokenObject.provenance;
    for (var provenanceObject in provenanceObjects) {
      final existingProvenanceObject = provenanceBox
          .query(ProvenanceObject_.uniqueId.equals(provenanceObject.uniqueId))
          .build()
          .findFirst();
      if (existingProvenanceObject != null) {
        provenanceObject.id = existingProvenanceObject.id;
      }
    }

    final existingTokenObject = assetTokenBox
        .query(AssetTokenObject_.uniqueId.equals(tokenObject.uniqueId))
        .build()
        .findFirst();
    if (existingTokenObject != null) {
      tokenObject.id = existingTokenObject.id;
    }

    tokenObject.asset.target = assetObject;
    try {
      final tokenId = assetTokenBox.put(tokenObject);
      return tokenId;
    } catch (e) {
      log.info('Error inserting asset token: $e');
      Sentry.captureException('Error inserting asset token: $e');
      rethrow;
    }
  }

  // insert asset tokens
  @override
  void insertAssetTokens(List<AssetToken> tokens) {
    for (final token in tokens) {
      insertAssetToken(token);
    }
  }

  /// Get all AssetTokens owned by a specific owner address.
  @override
  List<AssetToken> getAssetTokensByOwner(
      {required String ownerAddress,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime}) {
    final sortByProperty = convertSortByToQueryProperty(sortBy);
    final query = assetTokenBox
        .query(AssetTokenObject_.owner.equals(ownerAddress))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toAssetToken()).toList();
    } catch (e) {
      log.info('Error getting asset tokens by owner: $e');
      return [];
    } finally {
      query.close();
    }
  }

  @override
  List<AddressAssetTokens> getGroupAssetTokensByOwnersGroupByAddress(
      {required List<String> owners,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime}) {
    final groupByAddress = <AddressAssetTokens>[];
    log.info('[getGroupAssetTokensByOwnersGroupByAddress] Owners: $owners');
    for (final owner in owners) {
      final assetTokens =
          getAssetTokensByOwner(ownerAddress: owner, sortBy: sortBy);
      final address = assetTokens.first.owner;
      final compactedAssetTokens = assetTokens
          .map(
            (e) => CompactedAssetToken.fromAssetToken(
              e,
            ),
          )
          .toList();
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
          compactedAssetTokens: compactedAssetTokens,
        ),
      );
    }
    return groupByAddress;
  }

  /// get asset tokens by token ids
  @override
  List<AssetToken> getAssetTokensByIndexIds(
      {required List<String> indexIds,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime}) {
    final sortByProperty = convertSortByToQueryProperty(sortBy);
    final query = assetTokenBox
        .query(AssetTokenObject_.indexID.oneOf(indexIds))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toAssetToken()).toList();
    } catch (e) {
      log.info('Error getting asset tokens by index ids: $e');
      return [];
    } finally {
      query.close();
    }
  }

  @override
  void clearAll() {
    assetTokenBox.removeAll();
  }

  @override
  List<AssetToken> getAssetTokensByOwners(
      {required List<String> owners,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime}) {
    final sortByProperty = convertSortByToQueryProperty(sortBy);
    final query = assetTokenBox
        .query(AssetTokenObject_.owner.oneOf(owners))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toAssetToken()).toList();
    } catch (e) {
      log.info('Error getting asset tokens by owners: $e');
      return [];
    } finally {
      query.close();
    }
  }

  @override
  AssetToken? findAssetTokenByIdAndOwner(String id, String owner) {
    final query = assetTokenBox
        .query(AssetTokenObject_.indexID
            .equals(id)
            .and(AssetTokenObject_.owner.equals(owner)))
        .build();
    try {
      final results = query.find();
      return results.firstOrNull?.toAssetToken();
    } catch (e) {
      log.info('Error getting asset token by id and owner: $e');
      return null;
    } finally {
      query.close();
    }
  }
}
