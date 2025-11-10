// ignore_for_file: uri_does_not_exist, undefined_identifier
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:objectbox/objectbox.dart';

/// Base class for ObjectBox entities
abstract class ObjectboxEntity {
  @Unique()
  String uniqueId;

  ObjectboxEntity() : uniqueId = '';
}

/// ObjectBox persistence model for Token (v2)
@Entity(uid: 8)
class TokenObject extends ObjectboxEntity {
  int id;

  @override
  @Unique()
  String uniqueId;

  @Index()
  int tokenId;
  @Index()
  String cid;
  String chain;
  String standard;
  String contractAddress;
  String tokenNumber;
  String? currentOwner;
  // Store as microseconds since epoch to preserve microsecond precision
  // ObjectBox PropertyType.date only supports millisecond precision
  int? updatedAtMicroseconds;

  // store metadata JSON as string for flexibility
  String? metadataJson;
  // store related collections as JSON for flexibility
  String? ownersJson;
  String? provenanceEventsJson;
  String? enrichmentSourceJson;
  String? metadataMediaAssetsJson;
  String? enrichmentSourceMediaAssetsJson;

  TokenObject({
    this.id = 0,
    required this.tokenId,
    required this.cid,
    required this.chain,
    required this.standard,
    required this.contractAddress,
    required this.tokenNumber,
    this.currentOwner,
    this.updatedAtMicroseconds,
    this.metadataJson,
    this.ownersJson,
    this.provenanceEventsJson,
    this.enrichmentSourceJson,
    this.metadataMediaAssetsJson,
    this.enrichmentSourceMediaAssetsJson,
  }) : uniqueId = cid;

  factory TokenObject.fromToken(v2.AssetToken token) => TokenObject(
        tokenId: token.id,
        cid: token.cid,
        chain: token.chain,
        standard: token.standard,
        contractAddress: token.contractAddress,
        tokenNumber: token.tokenNumber,
        currentOwner: token.currentOwner,
        updatedAtMicroseconds: token.updatedAt?.microsecondsSinceEpoch,
        metadataJson: token.metadata != null
            ? json.encode(token.metadata!.toJson())
            : null,
        ownersJson:
            token.owners != null ? json.encode(token.owners!.toJson()) : null,
        provenanceEventsJson: token.provenanceEvents != null
            ? json.encode(token.provenanceEvents!.toJson())
            : null,
        enrichmentSourceJson: token.enrichmentSource != null
            ? json.encode(token.enrichmentSource!.toJson())
            : null,
        metadataMediaAssetsJson: token.metadataMediaAssets != null
            ? json.encode(
                token.metadataMediaAssets!.map((m) => m.toJson()).toList(),
              )
            : null,
        enrichmentSourceMediaAssetsJson:
            token.enrichmentSourceMediaAssets != null
                ? json.encode(
                    token.enrichmentSourceMediaAssets!
                        .map((m) => m.toJson())
                        .toList(),
                  )
                : null,
      );

  v2.AssetToken toToken() => v2.AssetToken(
        id: tokenId,
        cid: cid,
        chain: chain,
        standard: standard,
        contractAddress: contractAddress,
        tokenNumber: tokenNumber,
        currentOwner: currentOwner,
        updatedAt: updatedAtMicroseconds != null
            ? DateTime.fromMicrosecondsSinceEpoch(updatedAtMicroseconds!)
            : null,
        metadata: metadataJson != null
            ? v2.TokenMetadata.fromJson(
                Map<String, dynamic>.from(json.decode(metadataJson!) as Map),
              )
            : null,
        owners: ownersJson != null
            ? v2.PaginatedOwners.fromJson(
                Map<String, dynamic>.from(json.decode(ownersJson!) as Map),
              )
            : null,
        provenanceEvents: provenanceEventsJson != null
            ? v2.PaginatedProvenanceEvents.fromJson(
                Map<String, dynamic>.from(
                  json.decode(provenanceEventsJson!) as Map,
                ),
              )
            : null,
        enrichmentSource: enrichmentSourceJson != null
            ? v2.EnrichmentSource.fromJson(
                Map<String, dynamic>.from(
                  json.decode(enrichmentSourceJson!) as Map,
                ),
              )
            : null,
        metadataMediaAssets: metadataMediaAssetsJson != null
            ? (json.decode(metadataMediaAssetsJson!) as List)
                .map((e) =>
                    v2.MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : null,
        enrichmentSourceMediaAssets: enrichmentSourceMediaAssetsJson != null
            ? (json.decode(enrichmentSourceMediaAssetsJson!) as List)
                .map((e) =>
                    v2.MediaAsset.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList()
            : null,
      );
}
