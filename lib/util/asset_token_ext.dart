import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/blockchain.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/john_gerrard_helper.dart';
import 'package:collection/collection.dart';

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

  String get getMimeType {
    return RenderingType.image;
    //TODO: implement this
    //   switch (mimeType) {
    //     case 'image/avif':
    //     case 'image/bmp':
    //     case 'image/jpeg':
    //     case 'image/jpg':
    //     case 'image/png':
    //     case 'image/tiff':
    //       return RenderingType.image;

    //     case 'image/svg+xml':
    //       return RenderingType.svg;

    //     case 'image/gif':
    //     case 'image/vnd.mozilla.apng':
    //       return RenderingType.gif;

    //     case 'audio/aac':
    //     case 'audio/midi':
    //     case 'audio/x-midi':
    //     case 'audio/mpeg':
    //     case 'audio/ogg':
    //     case 'audio/opus':
    //     case 'audio/wav':
    //     case 'audio/webm':
    //     case 'audio/3gpp':
    //     case 'audio/vnd.wave':
    //       return RenderingType.audio;

    //     case 'video/x-msvideo':
    //     case 'video/3gpp':
    //     case 'video/mp4':
    //     case 'video/mpeg':
    //     case 'video/ogg':
    //     case 'video/3gpp2':
    //     case 'video/quicktime':
    //     case 'application/x-mpegURL':
    //     case 'video/x-flv':
    //     case 'video/MP2T':
    //     case 'video/webm':
    //     case 'application/octet-stream':
    //       return RenderingType.video;

    //     case 'application/pdf':
    //       return RenderingType.pdf;

    //     case 'model/gltf-binary':
    //       return RenderingType.modelViewer;

    //     default:
    //       if (mimeType?.isNotEmpty ?? false) {
    //         unawaited(
    //           Sentry.captureMessage(
    //             'Unsupport mimeType: $mimeType',
    //             level: SentryLevel.warning,
    //             params: [id],
    //           ),
    //         );
    //       }
    //       return mimeType ?? RenderingType.webview;
    //   }
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

    thumbnailUrl = enrichmentSourceMediaAssets
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

    return thumbnailUrl;
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
      return enrichmentSourceMediaAsset?.variantUrls.values.firstOrNull
          as String?;
    }

    // fallback to metadataMediaAssets
    final metadataMediaAssets = this.metadataMediaAssets;
    if (metadataMediaAssets != null) {
      final metadataMediaAsset = metadataMediaAssets.firstWhereOrNull(
          (mediaAsset) => mediaAsset.sourceUrl == animationUrl);
      return metadataMediaAsset?.variantUrls.values.firstOrNull as String?;
    }

    return null;
  }

  List<ProvenanceEvent> get provenance {
    return provenanceEvents?.items ?? [];
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
