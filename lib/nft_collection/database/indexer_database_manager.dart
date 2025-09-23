//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:objectbox/objectbox.dart';

import 'package:autonomy_flutter/nft_collection/models/asset.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/objectbox_entities.dart';

/// Simple manager wrapping ObjectBox operations for Indexer persistence.
class IndexerDataBaseManager {
  IndexerDataBaseManager(this.store)
      : assetBox = store.box<AssetObject>(),
        assetTokenBox = store.box<AssetTokenObject>();

  final Store store;
  final Box<AssetObject> assetBox;
  final Box<AssetTokenObject> assetTokenBox;

  /// Insert or update an AssetToken (domain) into ObjectBox as AssetTokenObject.
  /// If the token contains an Asset, it will be stored first and linked via ToOne.
  /// Returns the ObjectBox id of the stored AssetTokenObject.
  int insertAssetToken(AssetToken token) {
    AssetObject? assetObject;
    if (token.asset != null) {
      assetObject = AssetObject.fromAsset(token.asset!);
      final assetId = assetBox.put(assetObject);
      assetObject.id = assetId;
    }

    final tokenObject = AssetTokenObject.fromAssetToken(
      token,
      assetObject: assetObject,
    );

    final tokenId = assetTokenBox.put(tokenObject);
    return tokenId;
  }

  // insert asset tokens
  void insertAssetTokens(List<AssetToken> tokens) {
    final tokenObjects =
        tokens.map((e) => AssetTokenObject.fromAssetToken(e)).toList();
    assetTokenBox.putMany(tokenObjects);
  }

  /// Get all AssetTokens owned by a specific owner address.
  List<AssetToken> getAssetTokensByOwner(
      {required String ownerAddress,
      QueryProperty<AssetTokenObject, dynamic>? sortBy}) {
    final sortByProperty = sortBy ?? AssetTokenObject_.lastActivityTime;
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

  /// get asset tokens by token ids
  List<AssetToken> getAssetTokensByTokenIds(
      {required List<String> tokenIds,
      QueryProperty<AssetTokenObject, dynamic>? sortBy}) {
    final sortByProperty = sortBy ?? AssetTokenObject_.lastActivityTime;
    final query = assetTokenBox
        .query(AssetTokenObject_.indexID.oneOf(tokenIds))
        .order(sortByProperty, flags: Order.descending)
        .build();
    try {
      final results = query.find();
      return results.map((e) => e.toAssetToken()).toList();
    } finally {
      query.close();
    }
  }
}
