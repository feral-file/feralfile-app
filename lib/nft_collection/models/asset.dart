// ignore_for_file: public_member_api_docs, sort_constructors_first
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:floor/floor.dart';

class CompactedAsset {
  String? indexID;
  String? thumbnailID;
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

  CompactedAsset({
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
  });

  CompactedAsset.init({
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
  });

  factory CompactedAsset.fromAsset(Asset asset) {
    return CompactedAsset(
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
    );
  }

  factory CompactedAsset.fromJson(Map<String, dynamic> map) {
    return CompactedAsset(
      indexID: map['indexID'] != null ? map['indexID'] as String : null,
      thumbnailID:
          map['thumbnailID'] != null ? map['thumbnailID'] as String : null,
      lastRefreshedTime: map['lastRefreshedTime'] != null
          ? DateTime.tryParse(map['lastRefreshedTime'] as String)
          : null,
      artistID: map['metadata']['artistID'] != null
          ? map['artistID'] as String
          : null,
      artistName:
          map['artistName'] != null ? map['artistName'] as String : null,
      artistURL: map['artistURL'] != null ? map['artistURL'] as String : null,
      artists: map['artists'] != null ? map['artists'] as String : null,
      assetID: map['assetID'] != null ? map['assetID'] as String : null,
      title: map['title'] != null ? map['title'] as String : null,
      mimeType: map['mimeType'] != null ? map['mimeType'] as String : null,
      medium: map['medium'] as String?,
      source: map['source'] != null ? map['source'] as String : null,
      thumbnailURL:
          map['thumbnailURL'] != null ? map['thumbnailURL'] as String : null,
      galleryThumbnailURL: map['galleryThumbnailURL'] != null
          ? map['galleryThumbnailURL'] as String
          : null,
    );
  }
}

@Entity(primaryKeys: ['indexID'])
class Asset extends CompactedAsset {
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

  Asset({
    super.indexID,
    super.thumbnailID,
    super.lastRefreshedTime,
    super.artistID,
    super.artistName,
    super.artistURL,
    super.artists,
    super.assetID,
    super.title,
    super.mimeType,
    super.medium,
    super.source,
    super.thumbnailURL,
    super.galleryThumbnailURL,
    this.description,
    this.maxEdition,
    this.previewURL,
    this.assetData,
    this.assetURL,
    this.sourceURL,
    this.initialSaleModel,
    this.originalFileURL,
    this.isFeralfileFrame,
    this.artworkMetadata,
  });

  Asset.init({
    super.indexID,
    super.thumbnailID,
    super.lastRefreshedTime,
    super.artistID,
    super.artistName,
    super.artistURL,
    super.artists,
    super.assetID,
    super.title,
    super.mimeType,
    super.medium,
    super.source,
    super.thumbnailURL,
    super.galleryThumbnailURL,
    this.description,
    this.maxEdition,
    this.previewURL,
    this.assetData,
    this.assetURL,
    this.sourceURL,
    this.initialSaleModel,
    this.originalFileURL,
    this.isFeralfileFrame,
    this.artworkMetadata,
  }) : super.init();

  factory Asset.fromJson(Map<String, dynamic> map) {
    return Asset(
      indexID: map['indexID'] != null ? map['indexID'] as String : null,
      thumbnailID:
          map['thumbnailID'] != null ? map['thumbnailID'] as String : null,
      lastRefreshedTime: map['lastRefreshedTime'] != null
          ? DateTime.tryParse(map['lastRefreshedTime'] as String)
          : null,
      artistID: map['metadata']['artistID'] != null
          ? map['artistID'] as String
          : null,
      artistName:
          map['artistName'] != null ? map['artistName'] as String : null,
      artistURL: map['artistURL'] != null ? map['artistURL'] as String : null,
      artists: map['artists'] != null ? map['artists'] as String : null,
      assetID: map['assetID'] != null ? map['assetID'] as String : null,
      title: map['title'] != null ? map['title'] as String : null,
      description:
          map['description'] != null ? map['description'] as String : null,
      mimeType: map['mimeType'] != null ? map['mimeType'] as String : null,
      medium: map['medium'] as String?,
      maxEdition: map['maxEdition'] != null ? map['maxEdition'] as int : null,
      source: map['source'] != null ? map['source'] as String : null,
      sourceURL: map['sourceURL'] != null ? map['sourceURL'] as String : null,
      previewURL:
          map['previewURL'] != null ? map['previewURL'] as String : null,
      thumbnailURL:
          map['thumbnailURL'] != null ? map['thumbnailURL'] as String : null,
      galleryThumbnailURL: map['galleryThumbnailURL'] != null
          ? map['galleryThumbnailURL'] as String
          : null,
      assetData: map['assetData'] != null ? map['assetData'] as String : null,
      assetURL: map['assetURL'] != null ? map['assetURL'] as String : null,
      initialSaleModel: map['initialSaleModel'] != null
          ? map['initialSaleModel'] as String
          : null,
      originalFileURL: map['originalFileURL'] != null
          ? map['originalFileURL'] as String
          : null,
      isFeralfileFrame: map['isFeralfileFrame'] != null
          ? map['isFeralfileFrame'] as bool
          : null,
      artworkMetadata: map['artworkMetadata'] != null
          ? map['artworkMetadata'] as String
          : null,
    );
  }
}

String mediumFromMimeType(String? mimeType) {
  switch (mimeType) {
    case 'image/avif':
    case 'image/bmp':
    case 'image/jpeg':
    case 'image/jpg':
    case 'image/png':
    case 'image/tiff':
      return 'image';

    case 'image/svg+xml':
      return 'svg';

    case 'image/gif':
      return 'gif';

    case 'audio/aac':
    case 'audio/midi':
    case 'audio/x-midi':
    case 'audio/mpeg':
    case 'audio/ogg':
    case 'audio/opus':
    case 'audio/wav':
    case 'audio/webm':
    case 'audio/3gpp':
    case 'audio/vnd.wave':
      return 'audio';

    case 'video/x-msvideo':
    case 'video/3gpp':
    case 'video/mp4':
    case 'video/mpeg':
    case 'video/ogg':
    case 'video/3gpp2':
    case 'video/quicktime':
    case 'application/x-mpegURL':
    case 'video/x-flv':
    case 'video/MP2T':
    case 'video/webm':
    case 'application/octet-stream':
      return 'video';

    case 'application/pdf':
      return 'pdf';

    case 'model/gltf-binary':
      return 'model';

    default:
      return 'software';
  }
}
