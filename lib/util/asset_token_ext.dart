import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/address_service.dart';
import 'package:autonomy_flutter/nft_rendering/nft_rendering_widget.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/int_ext.dart';
import 'package:autonomy_flutter/util/john_gerrard_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:crypto/crypto.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:web3dart/crypto.dart';

extension AssetTokenExtension on AssetToken {
  bool get hasMetadata => galleryThumbnailURL != null;

  String get secondaryMarketURL {
    switch (blockchain) {
      case 'ethereum':
        return '$OPENSEA_ASSET_PREFIX/$contractAddress/$tokenId';
      case 'tezos':
        if (TEIA_ART_CONTRACT_ADDRESSES.contains(contractAddress)) {
          return '$TEIA_ART_ASSET_PREFIX$tokenId';
        } else if (sourceURL?.contains(FXHASH_IDENTIFIER) == true) {
          return assetURL ?? '';
        } else {
          return '$objktAssetPrefix$contractAddress/$tokenId';
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

  String get editionSlashMax {
    final editionStr = (editionName != null && editionName!.isNotEmpty)
        ? editionName
        : edition.toString();
    final hasNumber = RegExp('[0-9]').hasMatch(editionStr!);
    final maxEditionStr =
        (((maxEdition ?? 0) > 0) && hasNumber) ? '/$maxEdition' : '';
    return '$editionStr$maxEditionStr';
  }

  bool get isAirdrop {
    final saleModel = initialSaleModel?.toLowerCase();
    return ['airdrop', 'shopping_airdrop'].contains(saleModel);
  }

  String? getPreviewUrl() {
    if (previewURL != null) {
      final url = replaceIPFSPreviewURL(previewURL!);
      return url;
    }
    return null;
  }

  void updatePostcardCID(String cid) {
    if (Environment.appTestnetConfig) {
      asset?.previewURL = '$POSTCARD_IPFS_PREFIX_TEST/$cid/';
    } else {
      asset?.previewURL = '$POSTCARD_IPFS_PREFIX_PROD/$cid/';
    }
  }

  String? get feralfileArtworkId {
    if (!isFeralfile) {
      return null;
    }
    final artworkID = ((swapped ?? false) && originTokenInfoId != null)
        ? originTokenInfoId
        : id.split('-').last;
    return artworkID;
  }

  DP1Provenance get dp1Provenance {
    final chain = DP1ProvenanceChain.fromString(blockchain);
    final standard = this.isBitmarkToken
        ? DP1ProvenanceStandard.other
        : DP1ProvenanceStandard.fromString(contractType);
    final contractAddress = this.contractAddress!;
    final tokenId = this.tokenId;
    final dp1Contract = DP1Contract(
        chain: chain,
        standard: standard,
        address: contractAddress,
        tokenId: tokenId!);
    return DP1Provenance(
        type: DP1ProvenanceType.onChain, contract: dp1Contract);
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

extension CompactedAssetTokenExtension on CompactedAssetToken {
  bool get hasMetadata => galleryThumbnailURL != null;

  ArtworkIdentity get identity => ArtworkIdentity(id, owner);

  static final Map<String, Map<String, String>> _tokenUrlMap = {
    'MAIN': {
      'ethereum': 'https://etherscan.io/token/{contract}?a={tokenId}',
      'tezos': 'https://tzkt.io/{contract}/tokens/{tokenId}/transfers',
    },
    'TEST': {
      'ethereum': 'https://goerli.etherscan.io/token/{contract}?a={tokenId}',
      'tezos':
          'https://kathmandunet.tzkt.io/{contract}/tokens/{tokenId}/transfers',
    },
  };

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
    final title = asset?.title;
    if (title == null) {
      return null;
    }

    final isJohnGerrardSeries = asset?.assetID != null &&
        JohnGerrardHelper.assetIDs
            .any((id) => asset?.assetID!.startsWith(id) ?? false);

    if (mintedAt != null && !isJohnGerrardSeries)
      return '$title (${mintedAt!.year})';

    if (isFeralfile) {
      return '$title (${edition})';
    }

    return title;
  }

  String? get contractAddress {
    final splitted = id.split('-');
    return splitted.length > 1 ? splitted[1] : null;
  }

  bool get isFeralfile => source == 'feralfile';

  bool get shouldRefreshThumbnailCache =>
      isJohnGerrardArtwork &&
      edition > JohnGerrardHelper.johnGerrardLatestRevealIndex - 2;

  String? get tokenURL {
    final network = Environment.appTestnetConfig ? 'TEST' : 'MAIN';
    final url = _tokenUrlMap[network]?[blockchain]
        ?.replaceAll('{tokenId}', tokenId ?? '')
        .replaceAll('{contract}', contractAddress ?? '');
    return url;
  }

  String? tokenIdHex() => tokenId != null ? intToHex(tokenId!) : null;

  String digestHex2Hash(String tokenId) {
    final bigint = BigInt.tryParse(tokenId, radix: 10);
    if (bigint == null) {
      log.info('digestHex2Hash convert BigInt null');
      return '';
    }

    var hex = bigint.toRadixString(16);
    if (hex.length.isOdd) {
      hex = '0$hex';
    }
    final bytes = hexToBytes(hex);
    final hashHex = '0x${sha256.convert(bytes)}';
    return hashHex;
  }

  String? getBlockchainUrl() {
    final network = Environment.appTestnetConfig ? 'TESTNET' : 'MAINNET';
    switch ('${network}_$blockchain') {
      case 'MAINNET_ethereum':
        return 'https://etherscan.io/address/$contractAddress';

      case 'TESTNET_ethereum':
        return 'https://goerli.etherscan.io/address/$contractAddress';

      case 'MAINNET_tezos':
      case 'TESTNET_tezos':
        return 'https://tzkt.io/$contractAddress';
    }
    return null;
  }

  String get getMimeType {
    switch (mimeType) {
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
        if (mimeType?.isNotEmpty ?? false) {
          unawaited(
            Sentry.captureMessage(
              'Unsupport mimeType: $mimeType',
              level: SentryLevel.warning,
              params: [id],
            ),
          );
        }
        return mimeType ?? RenderingType.webview;
    }
  }

  bool get canInteract {
    final notSupportInteractMedium = [
      RenderingType.image,
      RenderingType.svg,
      RenderingType.gif,
    ];
    return !notSupportInteractMedium.contains(getMimeType);
  }

  int? get getCurrentBalance {
    return balance;
  }

  String? getGalleryThumbnailUrl({
    bool usingThumbnailID = true,
    String variant = 'thumbnail',
  }) {
    if (galleryThumbnailURL == null || galleryThumbnailURL!.isEmpty) {
      return null;
    }

    if (usingThumbnailID) {
      if (thumbnailID == null || thumbnailID!.isEmpty) {
        return replaceIPFS(galleryThumbnailURL!); // return null;
      }
      return _refineToCloudflareURL(
        galleryThumbnailURL!,
        thumbnailID!,
        variant,
      );
    }

    return replaceIPFS(galleryThumbnailURL!);
  }

  String get displayKey => id.hashCode.toString();

  List<Artist> get getArtists {
    final lst = jsonDecode(artists ?? '[]') as List<dynamic>;
    if (lst.length <= 1) {
      return [];
    }
    return lst
        .map((e) => Artist.fromJson((e as Map).typeCast<String, dynamic>()))
        .toList()
        .sublist(1);
  }

  bool get isMoMAMemento => [
        ...momaMementoContractAddresses,
        Environment.autonomyAirDropContractAddress,
      ].contains(contractAddress);

  bool get isWedgwoodActivationToken =>
      contractAddress == wedgwoodActivationContractAddress;

  bool get shouldShowFeralfileRight =>
      isFeralfile && !isWedgwoodActivationToken;

  Future<bool> hasLocalAddress() async {
    final owner = this.owner;
    final collectionAddresses =
        await injector<NftAddressService>().getAllAddresses();
    return collectionAddresses.any((element) => element.address == owner);
  }
}

String replaceIPFSPreviewURL(String url) {
  final newUrl =
      url.replacePrefix(IPFS_PREFIX, '${Environment.autonomyIpfsPrefix}/ipfs/');
  return newUrl.replacePrefix(
    DEFAULT_IPFS_PREFIX,
    Environment.autonomyIpfsPrefix,
  );
}

String replaceIPFS(String url) {
  final newUrl =
      url.replacePrefix(IPFS_PREFIX, '${Environment.autonomyIpfsPrefix}/ipfs/');
  return newUrl.replacePrefix(
    DEFAULT_IPFS_PREFIX,
    Environment.autonomyIpfsPrefix,
  );
}

String _refineToCloudflareURL(String url, String thumbnailID, String variant) {
  final cloudFlareImageUrlPrefix = Environment.cloudFlareImageUrlPrefix;
  return thumbnailID.isEmpty
      ? replaceIPFS(url)
      : '$cloudFlareImageUrlPrefix$thumbnailID/$variant';
}
