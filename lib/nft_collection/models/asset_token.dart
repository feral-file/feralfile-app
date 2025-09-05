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

class AssetToken {
  AssetToken({
    required this.id,
    required this.edition,
    required this.editionName,
    required this.blockchain,
    required this.fungible,
    required this.contractType,
    required this.tokenId,
    required this.contractAddress,
    required this.balance,
    required this.owner,
    required this.owners,
    required this.lastActivityTime,
    required this.lastRefreshedTime,
    required this.provenance,
    required this.originTokenInfo,
    this.mintedAt,
    this.projectMetadata,
    this.swapped = false,
    this.attributes,
    this.burned,
    this.ipfsPinned,
    this.asset,
    this.pending,
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
      attributes: json['asset']['attributes'] != null
          ? Attributes.fromJson(
              Map<String, dynamic>.from(json['asset']['attributes'] as Map),
            )
          : null,
      asset: projectMetadata.toAsset,
    );
  }

  String id;
  int edition;
  String? editionName;
  String blockchain;
  bool fungible;
  DateTime? mintedAt;
  String contractType;
  String? tokenId;
  String? contractAddress;
  int? balance;
  String owner;
  Map<String, int>
      owners; // Map from owner's address to number of owned tokens.
  ProjectMetadata? projectMetadata;
  DateTime lastActivityTime;
  DateTime lastRefreshedTime;
  List<Provenance> provenance;
  List<OriginTokenInfo>? originTokenInfo;
  bool? swapped;
  Attributes? attributes;

  bool? burned;
  bool? pending;
  bool? isManual;
  String? originTokenInfoId;
  bool? ipfsPinned;

  Asset? asset;

  String? get artistID => asset?.artistID;

  String? get artistName => asset?.artistName;

  String? get artistURL => asset?.artistURL;

  String? get artists => asset?.artists;

  String? get assetID => asset?.assetID;

  String? get title => asset?.title;

  String? get description => asset?.description;

  String? get mimeType => asset?.mimeType;

  String? get medium => asset?.mimeType != null && asset!.mimeType!.isNotEmpty
      ? mediumFromMimeType(asset!.mimeType!)
      : asset?.medium;

  int? get maxEdition => asset?.maxEdition;

  String? get source => asset?.source;

  String? get sourceURL => asset?.sourceURL;

  String? get previewURL => asset?.previewURL;

  String? get thumbnailURL => asset?.thumbnailURL;

  String? get thumbnailID => asset?.thumbnailID;

  String? get galleryThumbnailURL => asset?.galleryThumbnailURL;

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
        : projectMetadata?.origin.initialSaleModel;
  }
}

class CompactedAssetToken implements Comparable<CompactedAssetToken> {
  CompactedAssetToken({
    required this.id,
    required this.balance,
    required this.owner,
    required this.lastActivityTime,
    required this.lastRefreshedTime,
    required this.edition,
    this.mimeType,
    this.previewURL,
    this.thumbnailURL,
    this.thumbnailID,
    this.galleryThumbnailURL,
    this.pending,
    this.isDebugged,
    this.artistID,
    this.artistTitle,
    this.artistURL,
    this.blockchain,
    this.tokenId,
    this.title,
    this.source,
    this.mintedAt,
    this.assetID,
  });

  final String id;

  int? balance;
  String owner;

  final DateTime lastActivityTime;
  DateTime lastRefreshedTime;

  bool? pending;
  bool? isDebugged;

  String? mimeType;
  String? previewURL;
  String? thumbnailURL;
  String? thumbnailID;
  String? galleryThumbnailURL;
  String? artistID;
  String? artistTitle;
  String? artistURL;
  String? blockchain;
  String? tokenId;
  String? title;
  String? source;
  DateTime? mintedAt;
  String? assetID;
  int edition;

  factory CompactedAssetToken.fromAssetToken(AssetToken assetToken) {
    return CompactedAssetToken(
      id: assetToken.id,
      balance: assetToken.balance,
      owner: assetToken.owner,
      lastActivityTime: assetToken.lastActivityTime,
      lastRefreshedTime: assetToken.lastRefreshedTime,
      mimeType: assetToken.mimeType,
      previewURL: assetToken.previewURL,
      thumbnailURL: assetToken.thumbnailURL,
      thumbnailID: assetToken.thumbnailID,
      galleryThumbnailURL: assetToken.galleryThumbnailURL,
      pending: assetToken.pending,
      isDebugged: assetToken.isManual,
      artistID: assetToken.artistID,
      artistTitle: assetToken.artistName,
      artistURL: assetToken.artistURL,
      blockchain: assetToken.blockchain,
      tokenId: assetToken.tokenId,
      title: assetToken.title,
      source: assetToken.source,
      mintedAt: assetToken.mintedAt,
      assetID: assetToken.asset?.assetID,
      edition: assetToken.edition,
    );
  }

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

class ProjectMetadata {
  ProjectMetadata({
    required this.origin,
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
        origin: ProjectMetadataData.fromJson(
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

  ProjectMetadataData origin;
  ProjectMetadataData latest;

  Asset get toAsset => Asset(
        indexID,
        thumbnailID,
        lastRefreshedTime,
        latest.artistId,
        latest.artistName,
        latest.artistUrl,
        jsonEncode(latest.artists),
        latest.assetId,
        latest.title,
        latest.description,
        latest.mimeType,
        latest.medium,
        latest.maxEdition,
        latest.source,
        latest.sourceUrl,
        latest.previewUrl,
        latest.thumbnailUrl,
        latest.galleryThumbnailUrl,
        latest.assetData,
        latest.assetUrl,
        latest.initialSaleModel,
        latest.originalFileUrl,
        latest.artworkMetadata?['isFeralfileFrame'] as bool?,
        jsonEncode(latest.artworkMetadata),
      );

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
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
