// ignore_for_file: public_member_api_docs, sort_constructors_first
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:collection/collection.dart';
import 'package:floor_annotation/floor_annotation.dart';

@Entity(
  primaryKeys: [
    'id',
    'owner',
  ],
  indices: [
    Index(value: ['lastActivityTime', 'id']),
  ],
)
class Token {
  String id;
  String? tokenId;
  String blockchain;
  bool? fungible;
  String? contractType;
  String? contractAddress;
  int edition;
  String? editionName;
  DateTime? mintedAt;
  int? balance;
  String owner;
  Map<String, int> owners;
  String? source;
  bool? swapped;
  bool? burned;
  @ignore
  List<Provenance>? provenances;
  DateTime lastActivityTime;
  DateTime lastRefreshedTime;
  bool? ipfsPinned;

  bool? pending;
  bool? isDebugged;
  String? initialSaleModel;
  String? originTokenInfoId;
  String? indexID;

  Token({
    required this.id,
    required this.blockchain,
    required this.fungible,
    required this.contractType,
    required this.contractAddress,
    required this.edition,
    required this.editionName,
    required this.mintedAt,
    required this.balance,
    required this.owner,
    required this.owners,
    required this.source,
    required this.lastActivityTime,
    required this.lastRefreshedTime,
    this.tokenId,
    this.swapped = false,
    this.burned,
    this.provenances,
    this.ipfsPinned,
    this.pending,
    this.initialSaleModel,
    this.originTokenInfoId,
    this.indexID,
    this.isDebugged,
  });

  factory Token.fromAssetToken(AssetToken assetToken) => Token(
        blockchain: assetToken.blockchain,
        fungible: assetToken.fungible,
        contractType: assetToken.contractType,
        contractAddress: assetToken.contractAddress,
        edition: assetToken.edition,
        editionName: assetToken.editionName,
        id: assetToken.id,
        mintedAt: assetToken.mintedAt,
        source: assetToken.asset?.source,
        owners: assetToken.owners,
        balance: assetToken.balance,
        lastActivityTime: assetToken.lastActivityTime,
        provenances: assetToken.provenance,
        swapped: assetToken.swapped ?? false,
        owner: assetToken.owner,
        lastRefreshedTime: assetToken.lastRefreshedTime,
        burned: assetToken.burned,
        ipfsPinned: assetToken.ipfsPinned,
        originTokenInfoId: assetToken.originTokenInfo?.firstOrNull?.id,
        pending: assetToken.pending ?? false,
        tokenId: assetToken.tokenId,
        isDebugged: assetToken.isManual ?? false,
        indexID: assetToken.asset?.indexID,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          pending == other.pending;

  @override
  int get hashCode => id.hashCode;
}

class TokenOwnersConverter extends TypeConverter<Map<String, int>, String> {
  @override
  Map<String, int> decode(String? databaseValue) {
    if (databaseValue?.isNotEmpty == true) {
      return (json.decode(databaseValue!) as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, (value as int?) ?? 0)) ??
          {};
    } else {
      return {};
    }
  }

  @override
  String encode(Map<String, int>? value) {
    if (value == null) {
      return '{}';
    } else {
      return json.encode(value);
    }
  }
}
