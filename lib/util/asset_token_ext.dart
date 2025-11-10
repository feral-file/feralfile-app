import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/blockchain.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_changes.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/john_gerrard_helper.dart';
import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';

extension AssetTokenExtension on AssetToken {
  ArtworkIdentity get identity => ArtworkIdentity(cid);

  bool get isJohnGerrardArtwork {
    final contractAddress = this.contractAddress;
    final johnGerrardContractAddress = JohnGerrardHelper.contractAddress;
    return isFeralfile && contractAddress == johnGerrardContractAddress;
  }

  List<String> get disableKeys {
    if (isJohnGerrardArtwork) {
      return JohnGerrardHelper.disableKeys;
    }
    return [];
  }

  String? get displayTitle {
    var title = enrichmentSource?.name ?? metadata?.name;
    if (title == null) {
      return null;
    }

    if (isFeralfile) {
      title = '$title';
    }

    return title;
  }

  String get displayDescription {
    return enrichmentSource?.description ?? metadata?.description ?? '';
  }

  Publisher? get publisher => metadata?.publisher;

  bool get isFeralfile => publisher?.name == 'Feralfile';

  String? get _mimeType {
    return enrichmentSource?.mimeType ?? metadata?.mimeType;
  }

  String get getMimeType {
    switch (_mimeType) {
      case 'image/avif':
      case 'image/bmp':
      case 'image/jpeg':
      case 'image/jpg':
      case 'image/png':
      case 'image/tiff':
        return RenderingType.image;

      case 'image/svg+xml':
        return RenderingType.svg;

      case 'image/gif':
      case 'image/vnd.mozilla.apng':
        return RenderingType.gif;

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
        return RenderingType.audio;

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
        return RenderingType.video;

      case 'application/pdf':
        return RenderingType.pdf;

      case 'model/gltf-binary':
        return RenderingType.modelViewer;

      default:
        if (_mimeType?.isNotEmpty ?? false) {
          unawaited(
            Sentry.captureMessage(
              'Unsupport mimeType: $_mimeType',
              level: SentryLevel.warning,
              params: [cid],
            ),
          );
        }
        return _mimeType ?? RenderingType.webview;
    }
  }

  Blockchain get blockchain => Blockchain.fromChain(chain);

  bool get canInteract {
    final notSupportInteractMedium = [
      RenderingType.image,
      RenderingType.svg,
      RenderingType.gif,
    ];
    return !notSupportInteractMedium.contains(getMimeType);
  }

  String? getGalleryThumbnailUrl({
    bool usingThumbnailID = true,
    String variant = 'thumbnail',
  }) {
    String? thumbnailUrl;

    thumbnailUrl = enrichmentSource?.imageUrl ?? metadata?.imageUrl;

    final mediaThumbnailUrl = enrichmentSourceMediaAssets
            ?.firstWhereOrNull(
                (mediaAsset) => mediaAsset.sourceUrl == thumbnailUrl)
            ?.variantUrls
            .values
            .firstOrNull as String? ??
        metadataMediaAssets
            ?.firstWhereOrNull(
                (mediaAsset) => mediaAsset.sourceUrl == thumbnailUrl)
            ?.variantUrls
            .values
            .firstOrNull as String?;

    if (mediaThumbnailUrl != null && mediaThumbnailUrl.isNotEmpty) {
      return mediaThumbnailUrl;
    }

    if (thumbnailUrl?.isNotEmpty ?? false) {
      return thumbnailUrl;
    }

    return null;
  }

  String get displayKey => cid.hashCode.toString();

  List<Artist> get getArtists {
    return enrichmentSource?.artists ?? metadata?.artists ?? [];
  }

  bool get isWedgwoodActivationToken =>
      contractAddress == wedgwoodActivationContractAddress;

  bool get shouldShowFeralfileRight =>
      isFeralfile && !isWedgwoodActivationToken;

  bool hasLocalAddress() {
    final owners = this.owners;
    final collectionAddresses = injector<AddressService>().getAllAddresses();
    return collectionAddresses.any((element) =>
        owners?.items.any((owner) => owner.ownerAddress == element) ?? false);
  }

  String get secondaryMarketURL {
    switch (chain) {
      case 'ethereum':
        return '$OPENSEA_ASSET_PREFIX/$contractAddress/$tokenNumber';
      case 'tezos':
        if (TEIA_ART_CONTRACT_ADDRESSES.contains(contractAddress)) {
          return '$TEIA_ART_ASSET_PREFIX$tokenNumber';
        } else {
          return '$objktAssetPrefix$contractAddress/$tokenNumber';
        }
      default:
        return '';
    }
  }

  String get secondaryMarketName {
    final url = secondaryMarketURL;
    if (url.contains(OPENSEA_ASSET_PREFIX)) {
      return 'OpenSea';
    } else if (url.contains(FXHASH_IDENTIFIER)) {
      return 'FXHash';
    } else if (url.contains(TEIA_ART_ASSET_PREFIX)) {
      return 'Teia Art';
    } else if (url.contains(objktAssetPrefix)) {
      return 'Objkt';
    }
    return '';
  }

  String? get previewUrl {
    final animationUrl =
        enrichmentSource?.animationUrl ?? metadata?.animationUrl;

    if (animationUrl == null) {
      return null;
    }

    // search in enrichmentSourceMediaAssets
    final enrichmentSourceMediaAssets = this.enrichmentSourceMediaAssets;
    if (enrichmentSourceMediaAssets != null) {
      final enrichmentSourceMediaAsset =
          enrichmentSourceMediaAssets.firstWhereOrNull(
              (mediaAsset) => mediaAsset.sourceUrl == animationUrl);
      final variantUrl =
          enrichmentSourceMediaAsset?.variantUrls.values.firstOrNull as String?;
      if (variantUrl != null && variantUrl.isNotEmpty) {
        return variantUrl;
      }
    }

    // fallback to metadataMediaAssets
    final metadataMediaAssets = this.metadataMediaAssets;
    if (metadataMediaAssets != null) {
      final metadataMediaAsset = metadataMediaAssets.firstWhereOrNull(
          (mediaAsset) => mediaAsset.sourceUrl == animationUrl);

      final variantUrl =
          metadataMediaAsset?.variantUrls.values.firstOrNull as String?;
      if (variantUrl != null && variantUrl.isNotEmpty) {
        return variantUrl;
      }
    }

    if (animationUrl.isNotEmpty) {
      return animationUrl;
    }

    return getGalleryThumbnailUrl();
  }

  List<ProvenanceEvent> get provenance {
    return provenanceEvents?.items ?? [];
  }

  String? getBlockchainUrl() {
    switch (blockchain) {
      case Blockchain.ETHEREUM:
        return 'https://etherscan.io/address/$contractAddress';
      case Blockchain.TEZOS:
        return 'https://tzkt.io/$contractAddress';
    }
    return null;
  }

  /// Apply a Change (parsing its meta based on subjectType) and return updated token
  AssetToken applyChange(Change change) {
    final meta = change.metaParsed;
    final changedAt = change.changedAt;
    final lastUpdated = updatedAt;
    if (lastUpdated != null && lastUpdated.isAfter(changedAt)) {
      // NftCollection.logger.info(
      //     "[ApplyChange] token already updated: $cid, changedAt: $changedAt, updatedAt: $updatedAt");
      return this;
    }
    if (change.isMint()) {
      // if the change is a mint, no need to apply any change
      return this;
    }
    if (meta is ProvenanceChangeMeta) {
      return _applyProvenanceChangeMeta(meta, changedAt);
    } else if (meta is MetadataChangeMeta) {
      return _applyMetadataChangeMeta(meta, changedAt);
    } else {
      NftCollection.logger.info(
          "[ApplyChange] unknown change type: ${change.subjectType}, change: ${change.toJson()}");
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage("Unknown change type: ${change.subjectType}"),
        level: SentryLevel.info,
      )));
      return this;
    }
  }

  AssetToken _applyProvenanceChangeMeta(
    ProvenanceChangeMeta meta,
    DateTime? changedAt,
  ) {
    // Update currentOwner if 'to' address is provided
    String? newOwner = (currentOwner == meta.from) ? meta.to : currentOwner;

    // Update owners list if needed
    PaginatedOwners? newOwners = owners;
    if (meta.quantity != null) {
      final delta = _safeParseBigInt(meta.quantity!);
      final existingOwners = List<Owner>.from(owners?.items ?? []);
      final updated = <Owner>[];

      bool toUpdated = false;

      for (final owner in existingOwners) {
        // Subtract from 'from' address
        if (meta.from != null && owner.ownerAddress == meta.from) {
          final currentQty = _safeParseBigInt(owner.quantity);
          final next = currentQty - delta;
          if (next > BigInt.zero) {
            updated.add(owner.copyWith(quantity: next.toString()));
          }
          continue;
        }

        // Add to 'to' address
        if (meta.to != null && owner.ownerAddress == meta.to) {
          final currentQty = _safeParseBigInt(owner.quantity);
          final next = currentQty + delta;
          updated.add(owner.copyWith(quantity: next.toString()));
          toUpdated = true;
          continue;
        }

        // Keep unchanged owners
        updated.add(owner);
      }

      // If 'to' address not found, add it with delta
      if (meta.to != null && !toUpdated) {
        updated.add(Owner(ownerAddress: meta.to!, quantity: delta.toString()));
      }

      newOwners = (owners?.copyWith(items: updated)) ??
          PaginatedOwners(items: updated, offset: 0, total: updated.length);
    }

    return copyWith(
      currentOwner: newOwner,
      updatedAt: changedAt ?? updatedAt,
      owners: newOwners,
    );
  }

  AssetToken _applyMetadataChangeMeta(
    MetadataChangeMeta meta,
    DateTime? changedAt,
  ) {
    // Merge metadata fields: use new values, fallback to old if new is null
    final newMetadataFields = meta.new_;

    // Convert ChangeArtist to Artist
    List<Artist>? convertArtists(List<ChangeArtist>? changeArtists) {
      if (changeArtists == null) return null;
      return changeArtists
          .map((a) => Artist(did: a.did, name: a.name))
          .toList();
    }

    // Convert ChangePublisher to Publisher
    Publisher? convertPublisher(ChangePublisher? changePublisher) {
      if (changePublisher == null || changePublisher.name == null) {
        return null;
      }
      return Publisher(
        name: changePublisher.name,
        url: changePublisher.url,
      );
    }

    // Build new metadata by merging old and new, using copyWith if metadata exists
    final existingMetadata = metadata;
    final mergedMetadata = existingMetadata != null
        ? existingMetadata.copyWith(
            imageUrl: newMetadataFields.imageUrl ?? existingMetadata.imageUrl,
            animationUrl:
                newMetadataFields.animationUrl ?? existingMetadata.animationUrl,
            mimeType: newMetadataFields.mimeType ?? existingMetadata.mimeType,
            artists: convertArtists(newMetadataFields.artists) ??
                existingMetadata.artists,
            publisher: convertPublisher(newMetadataFields.publisher) ??
                existingMetadata.publisher,
          )
        : TokenMetadata(
            name: null,
            description: null,
            imageUrl: newMetadataFields.imageUrl,
            animationUrl: newMetadataFields.animationUrl,
            mimeType: newMetadataFields.mimeType,
            artists: convertArtists(newMetadataFields.artists),
            publisher: convertPublisher(newMetadataFields.publisher),
          );

    return copyWith(
      updatedAt: changedAt ?? updatedAt,
      metadata: mergedMetadata,
    );
  }
}

BigInt _safeParseBigInt(String value) {
  try {
    return BigInt.parse(value);
  } catch (_) {
    return BigInt.zero;
  }
}

String intToHex(String intValue) {
  try {
    final hex = BigInt.parse(intValue, radix: 10).toRadixString(16);
    return hex.padLeft(64, '0');
  } catch (e) {
    return intValue;
  }
}
