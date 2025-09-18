//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/nft_collection/models/asset.dart';
import 'package:autonomy_flutter/nft_collection/models/attributes.dart';
import 'package:autonomy_flutter/nft_collection/models/origin_token_info.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:autonomy_flutter/util/eth_utils.dart';

class CompactedAssetToken implements Comparable<CompactedAssetToken> {
  factory CompactedAssetToken.fromAssetToken(AssetToken assetToken) {
    return CompactedAssetToken(
      id: assetToken.id,
      balance: assetToken.balance,
      owner: assetToken.owner,
      lastActivityTime: assetToken.lastActivityTime,
      lastRefreshedTime: assetToken.lastRefreshedTime,
      pending: assetToken.pending,
      isDebugged: assetToken.isManual,
      blockchain: assetToken.blockchain,
      tokenId: assetToken.tokenId,
      mintedAt: assetToken.mintedAt,
      edition: assetToken.edition,
      asset: assetToken.asset != null
          ? CompactedAsset.fromAsset(assetToken.asset!)
          : null,
      editionName: assetToken.editionName,
    );
  }

  factory CompactedAssetToken.fromJsonGraphQl(Map<String, dynamic> json) {
    final rawOwnerList = (json['owners'] ?? <dynamic>[]) as List<dynamic>;
    final owners = <String, int>{};
    for (final rawOwner in rawOwnerList) {
      final owner = rawOwner as Map<String, dynamic>;
      owners[owner['address'] as String] = owner['balance'] as int;
    }
    final projectMetadata = ProjectMetadata.fromJson(
      Map<String, dynamic>.from(json['asset'] as Map),
    );

    return CompactedAssetToken(
      id: json['indexID'] as String,
      edition: json['edition'] as int,
      blockchain: json['blockchain'] as String,
      mintedAt: json['mintedAt'] != null
          ? DateTime.parse(json['mintedAt'] as String)
          : null,
      tokenId: json['id'] as String?,
      balance: json['balance'] as int,
      owner: json['owner'] as String,
      lastActivityTime: json['lastActivityTime'] != null
          ? DateTime.parse(json['lastActivityTime'] as String)
          : DateTime(1970),
      lastRefreshedTime: json['lastRefreshedTime'] != null
          ? DateTime.parse(json['lastRefreshedTime'] as String)
          : DateTime(1970),
      asset: projectMetadata.toAsset,
      editionName: json['editionName'] as String?,
      isDebugged: json['isDebugged'] as bool?,
      pending: json['pending'] as bool?,
    );
  }

  // copyWith
  CompactedAssetToken copyWith({
    String? id,
    int? balance,
    String? owner,
    DateTime? lastActivityTime,
    DateTime? lastRefreshedTime,
    int? edition,
    String? blockchain,
    String? tokenId,
    DateTime? mintedAt,
    covariant CompactedAsset? asset,
    String? editionName,
    bool? pending,
    bool? isDebugged,
  }) =>
      CompactedAssetToken(
        id: id ?? this.id,
        balance: balance ?? this.balance,
        owner: owner ?? this.owner,
        lastActivityTime: lastActivityTime ?? this.lastActivityTime,
        lastRefreshedTime: lastRefreshedTime ?? this.lastRefreshedTime,
        edition: edition ?? this.edition,
        blockchain: blockchain ?? this.blockchain,
        tokenId: tokenId ?? this.tokenId,
        mintedAt: mintedAt ?? this.mintedAt,
        asset: asset ?? this.asset,
        pending: pending ?? this.pending,
        isDebugged: isDebugged ?? this.isDebugged,
        editionName: editionName ?? this.editionName,
      );

  CompactedAssetToken({
    required this.id,
    required this.balance,
    required this.owner,
    required this.lastActivityTime,
    required this.lastRefreshedTime,
    required this.edition,
    this.editionName,
    this.pending,
    this.isDebugged,
    required this.blockchain,
    this.tokenId,
    this.mintedAt,
    this.asset,
  });

  final String id;
  final int? balance;
  final String owner;
  final DateTime lastActivityTime;
  final DateTime lastRefreshedTime;
  final bool? pending;
  final bool? isDebugged;
  final String blockchain;
  final String? tokenId;
  final DateTime? mintedAt;
  final int edition;
  final String? editionName;

  covariant CompactedAsset? asset;

  String? get artistID {
    final id = asset?.artistID;
    if (id == null || id.isEmpty) {
      return null;
    }

    if (id.isNullAddress) {
      return null;
    }

    return id;
  }

  String? get artistName {
    final name = asset?.artistName;
    if (name == null || name.isEmpty) {
      return null;
    }

    if (name.isNullAddress) {
      return null;
    }

    return name;
  }

  String? get artistURL => asset?.artistURL;

  String? get artists => asset?.artists;

  String? get assetID => asset?.assetID;

  // String? get displayTitle => asset?.title;

  String? get mimeType => asset?.mimeType;

  String? get medium => asset?.mimeType != null && asset!.mimeType!.isNotEmpty
      ? mediumFromMimeType(asset!.mimeType!)
      : asset?.medium;

  String? get source => asset?.source;

  String? get thumbnailURL => asset?.thumbnailURL;

  String? get thumbnailID => asset?.thumbnailID;

  String? get galleryThumbnailURL => asset?.galleryThumbnailURL;

  @override
  int compareTo(other) {
    if (other.id.compareTo(id) == 0 && other.owner.compareTo(owner) == 0) {
      return other.id.compareTo(id);
    }

    if (other.lastActivityTime.compareTo(lastActivityTime) == 0) {
      return other.id.compareTo(id);
    }

    return other.lastActivityTime.compareTo(lastActivityTime);
  }
}

class AssetToken extends CompactedAssetToken {
  AssetToken({
    required super.id,
    required super.edition,
    required super.editionName,
    required super.blockchain,
    required this.fungible,
    required this.contractType,
    required super.tokenId,
    required this.contractAddress,
    required super.balance,
    required super.owner,
    required this.owners,
    required super.lastActivityTime,
    required super.lastRefreshedTime,
    required this.provenance,
    required this.originTokenInfo,
    required super.isDebugged,
    super.mintedAt,
    this.projectMetadata,
    this.swapped = false,
    this.attributes,
    this.burned,
    this.ipfsPinned,
    this.asset,
    super.pending,
    this.isManual,
    this.originTokenInfoId,
  });

  factory AssetToken.fromJson(Map<String, dynamic> json) {
    final owners = (json['owners'] as Map?)?.map<String, int>(
          (key, value) => MapEntry(key as String, (value as int?) ?? 0),
        ) ??
        <String, int>{};
    final projectMetadata = ProjectMetadata.fromJson(
      Map<String, dynamic>.from(json['asset'] as Map),
    );

    return AssetToken(
      id: json['indexID'] as String,
      edition: json['edition'] as int,
      editionName: json['editionName'] as String?,
      blockchain: json['blockchain'] as String,
      fungible: json['fungible'] == true,
      mintedAt: json['mintedAt'] != null
          ? DateTime.parse(json['mintedAt'] as String)
          : null,
      contractType: json['contractType'] as String,
      tokenId: json['id'] as String?,
      contractAddress: json['contractAddress'] as String?,
      balance: json['balance'] as int,
      owner: json['owner'] as String,
      owners: owners,
      projectMetadata: projectMetadata,
      lastActivityTime: json['lastActivityTime'] != null
          ? DateTime.parse(json['lastActivityTime'] as String)
          : DateTime(1970),
      lastRefreshedTime: json['lastRefreshedTime'] != null
          ? DateTime.parse(json['lastRefreshedTime'] as String)
          : DateTime(1970),
      provenance: json['provenance'] != null
          ? (json['provenance'] as List<dynamic>)
              .asMap()
              .map<int, Provenance>(
                (key, value) => MapEntry(
                  key,
                  Provenance.fromJson(
                    Map<String, dynamic>.from(value as Map),
                    json['indexID'] as String,
                    key,
                  ),
                ),
              )
              .values
              .toList()
          : [],
      originTokenInfo: json['originTokenInfo'] != null
          ? (json['originTokenInfo'] as List<dynamic>)
              .map(
                (e) => OriginTokenInfo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : null,
      swapped: json['swapped'] as bool?,
      ipfsPinned: json['ipfsPinned'] as bool?,
      burned: json['burned'] as bool?,
      pending: json['pending'] as bool?,
      attributes: json['asset']['attributes'] != null
          ? Attributes.fromJson(
              Map<String, dynamic>.from(json['asset']['attributes'] as Map),
            )
          : null,
      asset: projectMetadata.toAsset,
      isDebugged: json['isDebugged'] as bool?,
    );
  }

  factory AssetToken.fromJsonGraphQl(Map<String, dynamic> json) {
    final rawOwnerList = (json['owners'] ?? <dynamic>[]) as List<dynamic>;
    final owners = <String, int>{};
    for (final rawOwner in rawOwnerList) {
      final owner = rawOwner as Map<String, dynamic>;
      owners[owner['address'] as String] = owner['balance'] as int;
    }
    final projectMetadata = ProjectMetadata.fromJson(
      Map<String, dynamic>.from(json['asset'] as Map),
    );

    return AssetToken(
      id: json['indexID'] as String,
      edition: json['edition'] as int,
      editionName: json['editionName'] as String?,
      blockchain: json['blockchain'] as String,
      fungible: json['fungible'] == true,
      mintedAt: json['mintedAt'] != null
          ? DateTime.parse(json['mintedAt'] as String)
          : null,
      contractType: json['contractType'] as String,
      tokenId: json['id'] as String?,
      contractAddress: json['contractAddress'] as String?,
      balance: json['balance'] as int,
      owner: json['owner'] as String,
      owners: owners,
      projectMetadata: projectMetadata,
      lastActivityTime: json['lastActivityTime'] != null
          ? DateTime.parse(json['lastActivityTime'] as String)
          : DateTime(1970),
      lastRefreshedTime: json['lastRefreshedTime'] != null
          ? DateTime.parse(json['lastRefreshedTime'] as String)
          : DateTime(1970),
      provenance: json['provenance'] != null
          ? (json['provenance'] as List<dynamic>)
              .asMap()
              .map<int, Provenance>(
                (key, value) => MapEntry(
                  key,
                  Provenance.fromJson(
                    Map<String, dynamic>.from(value as Map),
                    json['indexID'] as String,
                    key,
                  ),
                ),
              )
              .values
              .toList()
          : [],
      originTokenInfo: json['originTokenInfo'] != null
          ? (json['originTokenInfo'] as List<dynamic>)
              .map(
                (e) => OriginTokenInfo.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : null,
      swapped: json['swapped'] as bool?,
      ipfsPinned: json['ipfsPinned'] as bool?,
      burned: json['burned'] as bool?,
      pending: json['pending'] as bool?,
      isDebugged: json['isDebugged'] as bool?,
      attributes: json['asset']['attributes'] != null
          ? Attributes.fromJson(
              Map<String, dynamic>.from(json['asset']['attributes'] as Map),
            )
          : null,
      asset: projectMetadata.toAsset,
    );
  }

// String? id,
//     int? balance,
//     String? owner,
//     DateTime? lastActivityTime,
//     DateTime? lastRefreshedTime,
//     int? edition,
//     String? blockchain,
//     String? tokenId,
//     DateTime? mintedAt,
//     covariant CompactedAsset? asset,
//     String? editionName,
//     bool? pending,
//     bool? isDebugged,

  // copyWith method
  @override
  AssetToken copyWith({
    String? id,
    int? balance,
    String? owner,
    DateTime? lastActivityTime,
    DateTime? lastRefreshedTime,
    int? edition,
    String? blockchain,
    String? tokenId,
    DateTime? mintedAt,
    Asset? asset,
    String? editionName,
    bool? pending,
    bool? isDebugged,
    bool? fungible,
    String? contractType,
    String? contractAddress,
    Map<String, int>?
        owners, // Map from owner's address to number of owned tokens.
    ProjectMetadata? projectMetadata,
    List<Provenance>? provenance,
    List<OriginTokenInfo>? originTokenInfo,
    bool? swapped,
    Attributes? attributes,
    bool? burned,
    bool? isManual,
    String? originTokenInfoId,
    bool? ipfsPinned,
  }) {
    return AssetToken(
      id: id ?? this.id,
      edition: edition ?? this.edition,
      editionName: editionName ?? this.editionName,
      blockchain: blockchain ?? this.blockchain,
      fungible: fungible ?? this.fungible,
      mintedAt: mintedAt ?? this.mintedAt,
      contractType: contractType ?? this.contractType,
      tokenId: tokenId ?? this.tokenId,
      contractAddress: contractAddress ?? this.contractAddress,
      balance: balance ?? this.balance,
      owner: owner ?? this.owner,
      owners: owners ?? this.owners,
      projectMetadata: projectMetadata ?? this.projectMetadata,
      lastActivityTime: lastActivityTime ?? this.lastActivityTime,
      lastRefreshedTime: lastRefreshedTime ?? this.lastRefreshedTime,
      provenance: provenance ?? this.provenance,
      originTokenInfo: originTokenInfo ?? this.originTokenInfo,
      swapped: swapped ?? this.swapped,
      attributes: attributes ?? this.attributes,
      burned: burned ?? this.burned,
      pending: pending ?? this.pending,
      isManual: isManual ?? this.isManual,
      originTokenInfoId: originTokenInfoId ?? this.originTokenInfoId,
      ipfsPinned: ipfsPinned ?? this.ipfsPinned,
      asset: asset ?? this.asset,
      isDebugged: isDebugged ?? this.isDebugged,
    );
  }

  final bool fungible;
  final String contractType;
  final String? contractAddress;
  final Map<String, int>
      owners; // Map from owner's address to number of owned tokens.
  final ProjectMetadata? projectMetadata;
  final List<Provenance> provenance;
  final List<OriginTokenInfo>? originTokenInfo;
  final bool? swapped;
  final Attributes? attributes;

  final bool? burned;
  final bool? isManual;
  final String? originTokenInfoId;
  final bool? ipfsPinned;

  @override
  final Asset? asset;

  String? get description => asset?.description;

  int? get maxEdition => asset?.maxEdition;

  String? get sourceURL => asset?.sourceURL;

  String? get previewURL => asset?.previewURL;

  String? get assetData => asset?.assetData;

  String? get assetURL => asset?.assetURL;

  bool? get isFeralfileFrame => asset?.isFeralfileFrame;

  String? get initialSaleModel => asset?.initialSaleModel;

  String? get originalFileURL => asset?.originalFileURL;

  String? get artworkMetadata => asset?.artworkMetadata;

  bool get isBitmarkToken => id.startsWith('bmk-');

  String? get saleModel {
    final latestSaleModel = projectMetadata?.latest.initialSaleModel?.trim();
    return latestSaleModel?.isNotEmpty == true
        ? latestSaleModel
        : projectMetadata?.origin?.initialSaleModel;
  }
}

class ProjectMetadata {
  ProjectMetadata({
    this.origin,
    required this.latest,
    this.lastRefreshedTime,
    this.thumbnailID,
    this.indexID,
  });

  factory ProjectMetadata.fromJson(Map<String, dynamic> json) =>
      ProjectMetadata(
        indexID: json['indexID'] as String?,
        thumbnailID: json['thumbnailID'] as String?,
        lastRefreshedTime: json['lastRefreshedTime'] != null
            ? DateTime.tryParse(json['lastRefreshedTime'] as String)
            : null,
        origin: json['metadata']['project']['origin'] == null
            ? null
            : ProjectMetadataData.fromJson(
                Map<String, dynamic>.from(
                  json['metadata']['project']['origin'] as Map,
                ),
              ),
        latest: ProjectMetadataData.fromJson(
          Map<String, dynamic>.from(
            json['metadata']['project']['latest'] as Map,
          ),
        ),
      );

  String? indexID;
  String? thumbnailID;
  DateTime? lastRefreshedTime;

  ProjectMetadataData? origin;
  ProjectMetadataData latest;

  Asset get toAsset => Asset(
        indexID: indexID,
        thumbnailID: thumbnailID,
        lastRefreshedTime: lastRefreshedTime,
        artistID: latest.artistId,
        artistName: latest.artistName,
        artistURL: latest.artistUrl,
        artists: jsonEncode(latest.artists),
        assetID: latest.assetId,
        title: latest.title,
        description: latest.description,
        mimeType: latest.mimeType,
        medium: latest.medium,
        maxEdition: latest.maxEdition,
        source: latest.source,
        sourceURL: latest.sourceUrl,
        previewURL: latest.previewUrl,
        thumbnailURL: latest.thumbnailUrl,
        galleryThumbnailURL: latest.galleryThumbnailUrl,
        assetData: latest.assetData,
        assetURL: latest.assetUrl,
        initialSaleModel: latest.initialSaleModel,
        originalFileURL: latest.originalFileUrl,
        isFeralfileFrame: latest.artworkMetadata?['isFeralfileFrame'] as bool?,
        artworkMetadata: jsonEncode(latest.artworkMetadata),
      );

  CompactedAsset get toCompactedAsset => CompactedAsset(
        indexID: indexID,
        thumbnailID: thumbnailID,
        lastRefreshedTime: lastRefreshedTime,
        artistID: latest.artistId,
        artistName: latest.artistName,
        artistURL: latest.artistUrl,
        artists: jsonEncode(latest.artists),
        assetID: latest.assetId,
        title: latest.title,
        mimeType: latest.mimeType,
        medium: latest.medium,
        source: latest.source,
        thumbnailURL: latest.thumbnailUrl,
        galleryThumbnailURL: latest.galleryThumbnailUrl,
      );

  Map<String, dynamic> toJson() => {
        'origin': origin?.toJson(),
        'latest': latest.toJson(),
      };
}

class ProjectMetadataData {
  ProjectMetadataData({
    required this.artistName,
    required this.artistUrl,
    required this.artists,
    required this.assetId,
    required this.title,
    required this.description,
    required this.medium,
    required this.mimeType,
    required this.maxEdition,
    required this.baseCurrency,
    required this.basePrice,
    required this.source,
    required this.sourceUrl,
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.galleryThumbnailUrl,
    required this.assetData,
    required this.assetUrl,
    required this.artistId,
    required this.originalFileUrl,
    required this.initialSaleModel,
    required this.artworkMetadata,
  });

  factory ProjectMetadataData.fromJson(Map<String, dynamic> json) =>
      ProjectMetadataData(
        artistName: json['artistName'] as String?,
        artistUrl: json['artistURL'] as String?,
        artists: json['artists'] as List<dynamic>?,
        assetId: json['assetID'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        medium: json['medium'] as String?,
        mimeType: json['mimeType'] as String?,
        maxEdition: json['maxEdition'] as int?,
        baseCurrency: json['baseCurrency'] as String?,
        basePrice: json['basePrice']?.toDouble() as double?,
        source: json['source'] as String?,
        sourceUrl: json['sourceURL'] as String?,
        previewUrl: json['previewURL'] as String,
        thumbnailUrl: json['thumbnailURL'] as String,
        galleryThumbnailUrl: json['galleryThumbnailURL'] as String?,
        assetData: json['assetData'] as String?,
        assetUrl: json['assetURL'] as String?,
        artistId: json['artistID'] as String?,
        originalFileUrl: json['originalFileURL'] as String?,
        initialSaleModel: json['initialSaleModel'] as String?,
        artworkMetadata: json['artworkMetadata'] as Map<String, dynamic>?,
      );

  String? artistName;
  String? artistUrl;
  List<dynamic>? artists;
  String? assetId;
  String title;
  String? description;
  String? medium;
  String? mimeType;
  int? maxEdition;
  String? baseCurrency;
  double? basePrice;
  String? source;
  String? sourceUrl;
  String previewUrl;
  String thumbnailUrl;
  String? galleryThumbnailUrl;
  String? assetData;
  String? assetUrl;
  String? artistId;
  String? originalFileUrl;
  String? initialSaleModel;
  Map<String, dynamic>? artworkMetadata;

  Map<String, dynamic> toJson() => {
        'artistName': artistName,
        'artistURL': artistUrl,
        'artists': artists,
        'assetID': assetId,
        'title': title,
        'description': description,
        'medium': medium,
        'maxEdition': maxEdition,
        'baseCurrency': baseCurrency,
        'basePrice': basePrice,
        'source': source,
        'sourceURL': sourceUrl,
        'previewURL': previewUrl,
        'thumbnailURL': thumbnailUrl,
        'galleryThumbnailURL': galleryThumbnailUrl,
        'assetData': assetData,
        'assetURL': assetUrl,
        'artistID': artistId,
        'originalFileURL': originalFileUrl,
        'initialSaleModel': initialSaleModel,
        'artworkMetadata': artworkMetadata,
      };
}

class Artist {
  Artist({required this.name, this.id, this.url});

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String?,
      name: json['name'] as String,
      url: json['url'] as String?,
    );
  }

  final String? id;
  final String name;
  final String? url;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
    };
  }
}
