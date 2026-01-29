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
    String? size = 'xs',
  }) {
    String? thumbnailUrl;

    thumbnailUrl = enrichmentSource?.imageUrl ?? metadata?.imageUrl;

    if (size != null) {
      final metadataVariantUrls = metadataMediaAssets
          ?.firstWhereOrNull(
              (mediaAsset) => mediaAsset.sourceUrl == thumbnailUrl)
          ?.variantUrls;

      final enrichmentSourceVariantUrls = enrichmentSourceMediaAssets
          ?.firstWhereOrNull(
              (mediaAsset) => mediaAsset.sourceUrl == thumbnailUrl)
          ?.variantUrls;

      final mediaThumbnailUrl = (enrichmentSourceVariantUrls?[size] ??
              enrichmentSourceVariantUrls?.values.firstOrNull) as String? ??
          (metadataVariantUrls?[size] ??
              metadataVariantUrls?.values.firstOrNull) as String?;

      if (mediaThumbnailUrl != null && mediaThumbnailUrl.isNotEmpty) {
        thumbnailUrl = mediaThumbnailUrl;
      }
    }

    if (thumbnailUrl?.isNotEmpty ?? false) {
      if (size != null) {
        // if url in format https://imagedelivery.net/5BJzhBHeVhlhbn58hvcXAQ/../xl, then replace the /xl with size
        if (thumbnailUrl?.startsWith(
                'https://imagedelivery.net/5BJzhBHeVhlhbn58hvcXAQ/') ??
            false) {
          final urlParts = thumbnailUrl?.split('/');
          if (urlParts != null && urlParts.length > 2) {
            urlParts[urlParts.length - 1] = size;
            thumbnailUrl = urlParts.join('/');
          }
        }
      }
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

  String? getPreviewUrl() {
    final animationUrl =
        enrichmentSource?.animationUrl ?? metadata?.animationUrl;
    if (animationUrl?.isNotEmpty ?? false) {
      return animationUrl;
    }

    return getGalleryThumbnailUrl(size: null);
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
    final changedAt = change.createdAt;
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
      return _applyProvenanceChangeMeta(meta, change.changedAt);
    } else if (meta is MetadataChangeMeta) {
      return _applyMetadataChangeMeta(meta, changedAt);
    } else if (meta is EnrichmentSourceChangeMeta) {
      return _applyEnrichmentSourceChangeMeta(meta, changedAt);
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
    DateTime changedAt,
  ) {
    // Update currentOwner if 'to' address is provided
    String? newOwner = (currentOwner == meta.from) ? meta.to : currentOwner;

    final ProvenanceEventType provenanceEventType;
    if (meta.isMint()) {
      provenanceEventType = ProvenanceEventType.mint;
    } else if (meta.isBurn()) {
      provenanceEventType = ProvenanceEventType.burn;
    } else if (meta.isTransfer()) {
      provenanceEventType = ProvenanceEventType.transfer;
    } else {
      Sentry.captureEvent(SentryEvent(
        message:
            SentryMessage('Unknown provenance event type: ${meta.toJson()}'),
        level: SentryLevel.warning,
      ));
      provenanceEventType = ProvenanceEventType.unknown;
    }

    final provenanceEvent = ProvenanceEvent(
      chain: chain,
      eventType: provenanceEventType,
      fromAddress: meta.from,
      toAddress: meta.to,
      txHash: meta.txHash,
      timestamp: changedAt,
    );

    // check if the provenance event is already in the list
    if (provenanceEvents?.items.any((event) => event == provenanceEvent) ??
        false) {
      return this;
    }

    // Update owners list if needed
    PaginatedOwners? newOwners = owners;
    PaginatedProvenanceEvents? newProvenanceEvents = provenanceEvents;
    if (meta.quantity != null) {
      final delta = _safeParseBigInt(meta.quantity!);
      final existingOwners = List<Owner>.from(owners?.items ?? []);
      final updatedOwners = <Owner>[];

      bool toUpdated = false;

      for (final owner in existingOwners) {
        // Subtract from 'from' address
        if (meta.from != null && owner.ownerAddress == meta.from) {
          final currentQty = _safeParseBigInt(owner.quantity);
          final next = currentQty - delta;
          if (next > BigInt.zero) {
            updatedOwners.add(owner.copyWith(quantity: next.toString()));
          }
          continue;
        }

        // Add to 'to' address
        if (meta.to != null && owner.ownerAddress == meta.to) {
          final currentQty = _safeParseBigInt(owner.quantity);
          final next = currentQty + delta;
          updatedOwners.add(owner.copyWith(quantity: next.toString()));
          toUpdated = true;
          continue;
        }

        // Keep unchanged owners
        updatedOwners.add(owner);
      }

      // If 'to' address not found, add it with delta
      if (meta.to != null && !toUpdated) {
        updatedOwners
            .add(Owner(ownerAddress: meta.to!, quantity: delta.toString()));
      }

      newOwners = (owners?.copyWith(items: updatedOwners)) ??
          PaginatedOwners(
              items: updatedOwners, offset: 0, total: updatedOwners.length);

      final newProvenanceEventsItems = (provenanceEvents?.items ?? []).toList();
      newProvenanceEventsItems.add(provenanceEvent);
      // sort by timestamp descending
      newProvenanceEventsItems
          .sort((a, b) => b.timestamp.compareTo(a.timestamp));
      newProvenanceEvents =
          (provenanceEvents?.copyWith(items: newProvenanceEventsItems)) ??
              PaginatedProvenanceEvents(
                items: newProvenanceEventsItems,
                total: newProvenanceEventsItems.length,
                offset: null,
              );
    }

    return copyWith(
      currentOwner: newOwner,
      updatedAt: changedAt ?? changedAt,
      owners: newOwners,
      provenanceEvents: newProvenanceEvents,
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

  AssetToken _applyEnrichmentSourceChangeMeta(
    EnrichmentSourceChangeMeta meta,
    DateTime? changedAt,
  ) {
    // Merge enrichment source fields: use new values, fallback to old if new is null
    final newEnrichmentSourceFields = meta.new_;
    final oldEnrichmentSourceFields = meta.old;

    // Convert ChangeArtist to Artist
    List<Artist>? convertArtists(List<ChangeArtist>? changeArtists) {
      if (changeArtists == null) return null;
      return changeArtists
          .map((a) => Artist(did: a.did, name: a.name))
          .toList();
    }

    // Build new enrichment source by merging: new > old > existing
    final existingEnrichmentSource = enrichmentSource;
    final mergedEnrichmentSource = existingEnrichmentSource != null
        ? existingEnrichmentSource.copyWith(
            name: newEnrichmentSourceFields.name ??
                oldEnrichmentSourceFields.name ??
                existingEnrichmentSource.name,
            description: newEnrichmentSourceFields.description ??
                oldEnrichmentSourceFields.description ??
                existingEnrichmentSource.description,
            imageUrl: newEnrichmentSourceFields.imageUrl ??
                oldEnrichmentSourceFields.imageUrl ??
                existingEnrichmentSource.imageUrl,
            animationUrl: newEnrichmentSourceFields.animationUrl ??
                oldEnrichmentSourceFields.animationUrl ??
                existingEnrichmentSource.animationUrl,
            mimeType: newEnrichmentSourceFields.mimeType ??
                oldEnrichmentSourceFields.mimeType ??
                existingEnrichmentSource.mimeType,
            artists: convertArtists(newEnrichmentSourceFields.artists) ??
                convertArtists(oldEnrichmentSourceFields.artists) ??
                existingEnrichmentSource.artists,
          )
        : EnrichmentSource(
            name: newEnrichmentSourceFields.name ??
                oldEnrichmentSourceFields.name,
            description: newEnrichmentSourceFields.description ??
                oldEnrichmentSourceFields.description,
            imageUrl: newEnrichmentSourceFields.imageUrl ??
                oldEnrichmentSourceFields.imageUrl,
            animationUrl: newEnrichmentSourceFields.animationUrl ??
                oldEnrichmentSourceFields.animationUrl,
            mimeType: newEnrichmentSourceFields.mimeType ??
                oldEnrichmentSourceFields.mimeType,
            artists: convertArtists(newEnrichmentSourceFields.artists) ??
                convertArtists(oldEnrichmentSourceFields.artists),
          );

    return copyWith(
      updatedAt: changedAt ?? updatedAt,
      enrichmentSource: mergedEnrichmentSource,
    );
  }

  /// Get owner provenance for a specific address
  OwnerProvenance? ownerProvenanceForAddress(String address) {
    final normalizedAddress = address.toUpperCase();
    return ownerProvenances?.items.firstWhereOrNull(
      (p) => p.ownerAddress.toUpperCase() == normalizedAddress,
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
