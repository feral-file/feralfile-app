// ignore_for_file: uri_does_not_exist, undefined_identifier
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/nft_collection/models/asset.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/origin_token_info.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:objectbox/objectbox.dart';

/// Base class for ObjectBox entities
abstract class ObjectboxEntity {
  @Unique()
  String uniqueId;

  ObjectboxEntity() : uniqueId = '';
}

/// ObjectBox persistence model for Asset
@Entity()
class AssetObject extends ObjectboxEntity {
  /// ObjectBox internal id (auto-increment). Keep 0 for new objects.
  int id;

  String? indexID;

  @override
  @Unique()
  String uniqueId;

  String? thumbnailID;
  @Property(type: PropertyType.date)
  DateTime? lastRefreshedTime;
  String? artistID;
  String? artistName;
  String? artistURL;
  String? artists;
  String? assetID;
  String? title;
  String? mimeType;
  String? medium;
  String? source;
  String? thumbnailURL;
  String? galleryThumbnailURL;

  // Extended fields from Asset
  String? description;
  int? maxEdition;
  String? sourceURL;
  String? previewURL;
  String? assetData;
  String? assetURL;
  bool? isFeralfileFrame;
  String? initialSaleModel;
  String? originalFileURL;
  String? artworkMetadata;

  AssetObject({
    this.id = 0,
    this.indexID,
    this.thumbnailID,
    this.lastRefreshedTime,
    this.artistID,
    this.artistName,
    this.artistURL,
    this.artists,
    this.assetID,
    this.title,
    this.mimeType,
    this.medium,
    this.source,
    this.thumbnailURL,
    this.galleryThumbnailURL,
    this.description,
    this.maxEdition,
    this.sourceURL,
    this.previewURL,
    this.assetData,
    this.assetURL,
    this.isFeralfileFrame,
    this.initialSaleModel,
    this.originalFileURL,
    this.artworkMetadata,
  }) : uniqueId = '$indexID';

  factory AssetObject.fromAsset(Asset asset) => AssetObject(
        indexID: asset.indexID,
        thumbnailID: asset.thumbnailID,
        lastRefreshedTime: asset.lastRefreshedTime,
        artistID: asset.artistID,
        artistName: asset.artistName,
        artistURL: asset.artistURL,
        artists: asset.artists,
        assetID: asset.assetID,
        title: asset.title,
        mimeType: asset.mimeType,
        medium: asset.medium,
        source: asset.source,
        thumbnailURL: asset.thumbnailURL,
        galleryThumbnailURL: asset.galleryThumbnailURL,
        description: asset.description,
        maxEdition: asset.maxEdition,
        sourceURL: asset.sourceURL,
        previewURL: asset.previewURL,
        assetData: asset.assetData,
        assetURL: asset.assetURL,
        isFeralfileFrame: asset.isFeralfileFrame,
        initialSaleModel: asset.initialSaleModel,
        originalFileURL: asset.originalFileURL,
        artworkMetadata: asset.artworkMetadata,
      );

  Asset toAsset() => Asset(
        indexID: indexID,
        thumbnailID: thumbnailID,
        lastRefreshedTime: lastRefreshedTime,
        artistID: artistID,
        artistName: artistName,
        artistURL: artistURL,
        artists: artists,
        assetID: assetID,
        title: title,
        mimeType: mimeType,
        medium: medium,
        source: source,
        thumbnailURL: thumbnailURL,
        galleryThumbnailURL: galleryThumbnailURL,
        description: description,
        maxEdition: maxEdition,
        sourceURL: sourceURL,
        previewURL: previewURL,
        assetData: assetData,
        assetURL: assetURL,
        isFeralfileFrame: isFeralfileFrame,
        initialSaleModel: initialSaleModel,
        originalFileURL: originalFileURL,
        artworkMetadata: artworkMetadata,
      );
}

/// ObjectBox persistence model for AssetToken
/// Many AssetTokenObject -> One AssetObject (via ToOne relation)
@Entity()
class AssetTokenObject extends ObjectboxEntity {
  int id;

  // Core identifying fields
  @Index()
  String indexID; // same as AssetToken.id

  @Index()
  String owner;

  @override
  @Unique()
  String uniqueId;

  int edition;
  String blockchain;
  bool fungible;
  String contractType;
  String? contractAddress;
  String? tokenId;
  String? editionName;
  DateTime? mintedAt;
  int? balance;

  // store owners map as JSON string
  String ownersJson;

  // status/info fields
  @Property(type: PropertyType.date)
  DateTime lastActivityTime;
  @Property(type: PropertyType.date)
  DateTime lastRefreshedTime;
  bool? swapped;
  bool? burned;
  bool? ipfsPinned;
  bool? pending;
  bool? isDebugged;
  String? originTokenInfoId;

  // Relation to AssetObject
  final ToOne<AssetObject> asset;
  // 1 AssetTokenObject -> many ProvenanceObject
  final ToMany<ProvenanceObject> provenance;

  AssetTokenObject({
    this.id = 0,
    required this.indexID,
    required this.owner,
    required this.edition,
    required this.blockchain,
    required this.fungible,
    required this.contractType,
    this.contractAddress,
    this.tokenId,
    this.editionName,
    this.mintedAt,
    this.balance,
    required this.ownersJson,
    required this.lastActivityTime,
    required this.lastRefreshedTime,
    this.swapped,
    this.burned,
    this.ipfsPinned,
    this.pending,
    this.isDebugged,
    this.originTokenInfoId,
  })  : asset = ToOne<AssetObject>(),
        provenance = ToMany<ProvenanceObject>(),
        uniqueId = '$indexID-$owner';

  factory AssetTokenObject.fromAssetToken(AssetToken token) {
    final obj = AssetTokenObject(
      indexID: token.id,
      owner: token.owner,
      edition: token.edition,
      blockchain: token.blockchain,
      fungible: token.fungible,
      contractType: token.contractType,
      contractAddress: token.contractAddress,
      tokenId: token.tokenId,
      editionName: token.editionName,
      mintedAt: token.mintedAt,
      balance: token.balance,
      ownersJson: json.encode(token.owners),
      lastActivityTime: token.lastActivityTime,
      lastRefreshedTime: token.lastRefreshedTime,
      swapped: token.swapped,
      burned: token.burned,
      ipfsPinned: token.ipfsPinned,
      pending: token.pending,
      isDebugged: token.isDebugged,
      originTokenInfoId: token.originTokenInfoId,
    );
    if (token.asset != null) {
      obj.asset.target = AssetObject.fromAsset(token.asset!);
    }
    // set provenance relation
    if (token.provenance.isNotEmpty) {
      obj.provenance.addAll(
        token.provenance
            .map((p) => ProvenanceObject.fromProvenance(p))
            .toList(),
      );
    }
    return obj;
  }

  AssetToken toAssetToken() => AssetToken(
        id: indexID,
        edition: edition,
        editionName: editionName,
        blockchain: blockchain,
        fungible: fungible,
        mintedAt: mintedAt,
        contractType: contractType,
        tokenId: tokenId,
        contractAddress: contractAddress,
        balance: balance,
        owner: owner,
        owners: Map<String, int>.from(json.decode(ownersJson) as Map),
        lastActivityTime: lastActivityTime,
        lastRefreshedTime: lastRefreshedTime,
        provenance:
            provenance.map((p) => p.toProvenance()).toList(growable: false),
        originTokenInfo: <OriginTokenInfo>[],
        swapped: swapped,
        attributes: null,
        burned: burned,
        pending: pending,
        isManual: isDebugged,
        originTokenInfoId: originTokenInfoId,
        ipfsPinned: ipfsPinned,
        asset: asset.target?.toAsset(),
        isDebugged: isDebugged,
      );
}

//ProvenanceObject
@Entity()
class ProvenanceObject extends ObjectboxEntity {
  int id;

  String provenanceId; // same as Provenance.id

  @override
  @Unique()
  String uniqueId;

  String txID;
  String type;
  String blockchain;
  String owner;
  @Property(type: PropertyType.date)
  DateTime timestamp;
  String txURL;
  String tokenID; // indexer token id (matches AssetTokenObject.indexID)
  int? blockNumber;

  ProvenanceObject({
    this.id = 0,
    required this.provenanceId,
    required this.txID,
    required this.type,
    required this.blockchain,
    required this.owner,
    required this.timestamp,
    required this.txURL,
    required this.tokenID,
    this.blockNumber,
  }) : uniqueId = '$txID-$type-$owner';

  factory ProvenanceObject.fromProvenance(
    Provenance provenance,
  ) {
    final obj = ProvenanceObject(
      provenanceId: provenance.id,
      txID: provenance.txID,
      type: provenance.type,
      blockchain: provenance.blockchain,
      owner: provenance.owner,
      timestamp: provenance.timestamp,
      txURL: provenance.txURL,
      tokenID: provenance.tokenID,
      blockNumber: provenance.blockNumber,
    );
    return obj;
  }

  Provenance toProvenance() => Provenance(
        id: provenanceId,
        type: type,
        blockchain: blockchain,
        txID: txID,
        owner: owner,
        timestamp: timestamp,
        txURL: txURL,
        tokenID: tokenID,
        blockNumber: blockNumber,
      );
}
