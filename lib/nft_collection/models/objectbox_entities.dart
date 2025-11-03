// ignore_for_file: uri_does_not_exist, undefined_identifier
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:objectbox/objectbox.dart';

/// Base class for ObjectBox entities
abstract class ObjectboxEntity {
  @Unique()
  String uniqueId;

  ObjectboxEntity() : uniqueId = '';
}

/// ObjectBox persistence model for Token (v2)
@Entity()
class TokenObject extends ObjectboxEntity {
  int id;

  @override
  @Unique()
  String uniqueId;

  @Index()
  String cid;
  String chain;
  String standard;
  String contractAddress;
  String tokenNumber;
  String? currentOwner;
  bool burned;
  @Property(type: PropertyType.date)
  DateTime createdAt;
  @Property(type: PropertyType.date)
  DateTime updatedAt;

  // store metadata JSON as string for flexibility
  String? metadataJson;

  TokenObject({
    this.id = 0,
    required this.cid,
    required this.chain,
    required this.standard,
    required this.contractAddress,
    required this.tokenNumber,
    this.currentOwner,
    required this.burned,
    required this.createdAt,
    required this.updatedAt,
    this.metadataJson,
  }) : uniqueId = cid;

  factory TokenObject.fromToken(v2.AssetToken token) => TokenObject(
        cid: token.cid,
        chain: token.chain,
        standard: token.standard,
        contractAddress: token.contractAddress,
        tokenNumber: token.tokenNumber,
        currentOwner: token.currentOwner,
        burned: token.burned,
        createdAt: token.createdAt,
        updatedAt: token.updatedAt,
        metadataJson: token.metadata != null
            ? json.encode({
                'token_id': token.metadata!.tokenId,
                'origin_json': token.metadata!.originJson,
                'latest_json': token.metadata!.latestJson,
                'latest_hash': token.metadata!.latestHash,
                'enrichment_level': token.metadata!.enrichmentLevel,
                'last_refreshed_at':
                    token.metadata!.lastRefreshedAt?.toIso8601String(),
                'image_url': token.metadata!.imageUrl,
                'animation_url': token.metadata!.animationUrl,
                'name': token.metadata!.name,
                'description': token.metadata!.description,
                'artists':
                    token.metadata!.artists?.map((a) => a.toMap()).toList(),
                'publisher': token.metadata!.publisher?.toMap(),
              })
            : null,
      );

  v2.AssetToken toToken() => v2.AssetToken(
        cid: cid,
        chain: chain,
        standard: standard,
        contractAddress: contractAddress,
        tokenNumber: tokenNumber,
        currentOwner: currentOwner,
        burned: burned,
        createdAt: createdAt,
        updatedAt: updatedAt,
        metadata: metadataJson != null
            ? v2.TokenMetadata.fromMap(
                Map<String, dynamic>.from(json.decode(metadataJson!) as Map),
              )
            : null,
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
  String tokenID; // matches TokenObject.cid
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
