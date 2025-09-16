import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/common.dart';
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/crawl_helper.dart';
import 'package:autonomy_flutter/util/helpers.dart';
import 'package:autonomy_flutter/util/http_helper.dart';
import 'package:autonomy_flutter/util/john_gerrard_helper.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:collection/collection.dart';
import 'package:sentry/sentry.dart';

extension ExhibitionExt on Exhibition {
  String get coverUrl {
    final uri = (coverDisplay?.isNotEmpty == true) ? coverDisplay! : coverURI;
    return getFFUrl(uri);
  }

  bool get isGroupExhibition => type == 'group';

  bool get isSoloExhibition => type == 'solo';

  bool get isJohnGerrardShow => id == JohnGerrardHelper.exhibitionID;

  bool get isCrawlShow => id == CrawlHelper.exhibitionID;

  bool get isSourceExhibition => id == SOURCE_EXHIBITION_ID;

  DateTime get exhibitionViewAt =>
      exhibitionStartAt.subtract(Duration(seconds: previewDuration ?? 0));

  String get displayKey => id;

  //TODO: implement this
  bool get isOnGoing => true;

  bool get isMinted => status == ExhibitionStatus.issued.index;

  List<FFSeries> get displayableSeries => series?.displayable ?? [];

  List<String> get disableKeys {
    if (isJohnGerrardShow) {
      JohnGerrardHelper.disableKeys;
    }
    return [];
  }

  String? get getSeriesArtworkModelText {
    if (this.series == null || id == SOURCE_EXHIBITION_ID) {
      return null;
    }
    const sep = ', ';
    final specifiedSeriesArtworkModelTitle =
        injector<RemoteConfigService>().getConfig<Map<String, dynamic>>(
      ConfigGroup.exhibition,
      ConfigKey.specifiedSeriesArtworkModelTitle,
      specifiedSeriesTitle,
    );
    final specifiedSeriesIds = specifiedSeriesArtworkModelTitle.keys;
    final currentSpecifiedSeries = this
        .series!
        .where((element) => specifiedSeriesIds.contains(element.id))
        .toList();
    final series = this
        .series!
        .where((element) => !currentSpecifiedSeries.contains(element))
        .toList();

    final map = <String, List<FFSeries>>{};
    for (final s in series) {
      final saleModel = s.settings?.artworkModel?.value;
      if (map.containsKey(saleModel)) {
        map[saleModel]!.add(s);
      } else {
        map[saleModel ?? ''] = [s];
      }
    }
    final keys = map.keys.toList().sorted(
          (a, b) =>
              (ArtworkModel.fromString(b)?.index ?? 0) -
              (ArtworkModel.fromString(a)?.index ?? 0),
        );
    var text = '';
    for (final key in keys) {
      final length = map[key]!.length;
      final model = ArtworkModel.fromString(key);
      final modelTitle = length == 1 ? model?.title : model?.pluralTitle;
      text += '$length $modelTitle$sep';
    }

    final currentSpecifiedSeriesArtworkModelTitleMap = <String, List<String>>{};
    for (final s in currentSpecifiedSeries) {
      final saleModel = specifiedSeriesArtworkModelTitle[s.id] as String? ?? '';
      if (currentSpecifiedSeriesArtworkModelTitleMap.containsKey(saleModel)) {
        currentSpecifiedSeriesArtworkModelTitleMap[saleModel]!.add(s.title);
      } else {
        currentSpecifiedSeriesArtworkModelTitleMap[saleModel] = [s.title];
      }
    }

    currentSpecifiedSeriesArtworkModelTitleMap.forEach((key, value) {
      final model = ExtendedArtworkModel.fromTitle(key);
      final modelTitle =
          (value.length == 1 ? model?.title : model?.pluralTitle) ?? key;
      text += '${value.length} $modelTitle$sep';
    });
    final res = text.substring(0, text.length - 2);
    final index = text.substring(0, text.length - 2).lastIndexOf(sep);
    const lastSep = ' and ';
    return index == -1
        ? res
        : res.replaceRange(
            index,
            index + sep.length,
            lastSep,
          );
  }

  List<CustomExhibitionNote> get customExhibitionNote {
    final customNote = <CustomExhibitionNote>[];
    if (isJohnGerrardShow) {
      customNote.addAll(JohnGerrardHelper.customNote);
    }
    return customNote;
  }

  List<String> get foreWord {
    final config =
        injector<RemoteConfigService>().getConfig<Map<String, dynamic>>(
      ConfigGroup.exhibition,
      ConfigKey.foreWord,
      {},
    );
    final forewords = List<String>.from(config[id] as List? ?? []);
    return forewords;
  }

  // get all resource, include posts and custom notes
  List<Resource> get allResources {
    final resources = <Resource>[...customExhibitionNote];
    if (posts != null) {
      resources.addAll(posts!);
    }
    return resources;
  }

  bool get shouldShowCuratorNote => noteBrief?.isNotEmpty == true;

  bool get shouldShowCuratorNotePage =>
      shouldShowCuratorNote || allResources.isNotEmpty || foreWord.isNotEmpty;
}

extension ListExhibitionDetailExt on List<ExhibitionDetail> {
  List<Exhibition> get exhibitions => map((e) => e.exhibition).toList();
}

extension ExhibitionDetailExt on ExhibitionDetail {
  String? getArtworkTokenId(Artwork artwork) {
    if (artwork.swap != null) {
      if (artwork.swap!.token == null) {
        return null;
      }
      final chain = artwork.swap!.blockchainType == 'ethereum' ? 'eth' : 'tez';
      final contract = artwork.swap!.contractAddress;
      final id = chain == 'eth'
          ? artwork.swap!.token!.hexToDecimal
          : artwork.swap!.token;
      return '$chain-$contract-$id';
    } else {
      final chain = exhibition.mintBlockchain == 'ethereum' ? 'eth' : 'tez';
      final contract = exhibition.contracts?.firstWhereOrNull(
        (e) => e.blockchainType == exhibition.mintBlockchain,
      );
      final contractAddress = contract?.address;
      if (contractAddress == null) {
        return null;
      }
      final id = artwork.id;
      return '$chain-$contractAddress-$id';
    }
  }
}

// Artwork Ext
extension ArtworkExt on Artwork {
  String get smallThumbnailURL {
    final uri = (thumbnailDisplay?.isNotEmpty ?? false)
        ? thumbnailDisplay!
        : thumbnailURI;
    return getFFUrl(uri, variant: CloudFlareVariant.m.value);
  }

  String get thumbnailURL {
    final uri = (thumbnailDisplay?.isNotEmpty == true)
        ? thumbnailDisplay!
        : thumbnailURI;
    return getFFUrl(uri, variant: CloudFlareVariant.l.value);
  }

  bool get isFeralfileFrame => series?.isFeralfileFrame ?? false;

  String get previewURL {
    final displayUri =
        Platform.isAndroid ? (previewDisplay?['DASH']) : previewDisplay?['HLS'];
    String uri;
    if (displayUri?.isNotEmpty == true) {
      final bandWidth = injector<RemoteConfigService>().getConfig<double?>(
        ConfigGroup.videoSettings,
        ConfigKey.clientBandwidthHint,
        null,
      );
      uri = _urlWithClientBandwidthHint(displayUri!, bandWidth);
    } else {
      uri = previewURI;
    }
    return getFFUrl(uri);
  }

  bool get isCrystallineWork =>
      series?.exhibitionID == JohnGerrardHelper.exhibitionID;

  String _urlWithClientBandwidthHint(String uri, double? bandwidth) {
    final queryParameters = <String, String>{};
    if (bandwidth != null) {
      queryParameters['bandwidth'] = bandwidth.toString();
    }
    final urlWithClientBandwidthHint = Uri.tryParse(uri)?.replace(
      queryParameters: queryParameters,
    );
    return urlWithClientBandwidthHint.toString();
  }

  bool get isScrollablePreviewURL {
    final remoteConfigService = injector<RemoteConfigService>();
    final scrollablePreviewURL = remoteConfigService.getConfig<List<String>?>(
      ConfigGroup.feralfileArtworkAction,
      ConfigKey.scrollablePreviewUrl,
      [],
    );
    return scrollablePreviewURL?.contains(previewURL) ?? true;
  }

  String get metricTokenId => '${seriesID}_$id';

  Future<String> renderingType() async {
    final medium = series?.medium ?? 'unknown';
    final mediumType = FeralfileMediumTypes.fromString(medium);
    if (mediumType == FeralfileMediumTypes.image) {
      final contentType = await HttpHelper.contentType(previewURL);
      return contentType;
    } else {
      return mediumType.toRenderingType;
    }
  }

  String? get attributesString {
    if (artworkAttributes == null) {
      return null;
    }

    return artworkAttributes!
        .map((e) => '${e.traitType}: ${e.value}')
        .join('. ');
  }

  FFContract? getContract(Exhibition? exhibition) {
    if (swap != null) {
      if (swap!.token == null) {
        return null;
      }

      return FFContract(
        swap!.contractName,
        swap!.blockchainType,
        swap!.contractAddress,
      );
    }

    return exhibition?.contracts?.firstWhereOrNull(
      (e) => e.blockchainType == exhibition.mintBlockchain,
    );
  }

  String? get indexerTokenId {
    final chainPrefix = _getChainPrefix();
    final contractAddress = _getContractAddress();
    final indexId = _getIndexId();

    if (chainPrefix == null || contractAddress == null || indexId == null) {
      return null;
    }

    return '$chainPrefix-$contractAddress-$indexId';
  }

  DP1Item? get dp1Item {
    final chainPrefix = _getChainPrefix();
    final contractAddress = _getContractAddress();
    final indexId = _getIndexId();

    if (chainPrefix == null || contractAddress == null || indexId == null) {
      return null;
    }

    final dp1Chain = chainPrefix == 'eth'
        ? DP1ProvenanceChain.evm
        : (chainPrefix == 'tez'
            ? DP1ProvenanceChain.tezos
            : DP1ProvenanceChain.bitmark);

    final standard =
        series?.exhibition?.mintBlockchain.toLowerCase() == 'ethereum'
            ? DP1ProvenanceStandard.erc721
            : (series?.exhibition?.mintBlockchain.toLowerCase() == 'tezos'
                ? DP1ProvenanceStandard.fa2
                : DP1ProvenanceStandard.other);

    return DP1Item(
        title: this.name,
        source: previewURL,
        duration: 5 * 60,
        provenance: DP1Provenance(
            type: DP1ProvenanceType.onChain,
            contract: DP1Contract(
                chain: dp1Chain, address: contractAddress, tokenId: indexId)));
  }

  /// Get chain prefix for indexerTokenId
  /// Returns null if chain is not supported or invalid
  String? _getChainPrefix() {
    final chain = series?.exhibition?.mintBlockchain.toLowerCase();
    if (chain == null || chain.isEmpty) {
      return null;
    }

    // normal case: tezos or ethereum chain
    if (['tezos', 'ethereum'].contains(chain)) {
      return chain == 'tezos' ? 'tez' : 'eth';
    } else if (chain == 'bitmark') {
      // if artwork was burned, get chain prefix from swap
      if (swap != null) {
        final swapChain = swap!.blockchainType == 'ethereum' ? 'eth' : 'tez';
        return swapChain;
      } else {
        return 'bmk';
      }
    } else {
      unawaited(
        Sentry.captureMessage(
          'ArtworkExt: get chain prefix failed, '
          'unknown chain: $chain, artworkID: $id',
        ),
      );
    }
    return null;
  }

  /// Get contract address for indexerTokenId
  /// Returns null if contract is not found or invalid
  String? _getContractAddress() {
    final chain = series?.exhibition?.mintBlockchain.toLowerCase();
    if (chain == null || chain.isEmpty) {
      return null;
    }

    // normal case: tezos or ethereum chain
    if (['tezos', 'ethereum'].contains(chain)) {
      final contract = series!.exhibition!.contracts?.firstWhereOrNull(
        (e) => e.blockchainType == chain,
      );
      if (contract == null) {
        unawaited(
          Sentry.captureMessage(
            'ArtworkExt: get contract address failed,'
            ' contract is null for chain: $chain, artworkID: $id',
          ),
        );
        return null;
      }
      return contract.address;
    } else if (chain == 'bitmark') {
      // if artwork was burned, get contract address from swap
      if (swap != null) {
        return swap!.contractAddress;
      } else {
        final contract = series!.exhibition!.contracts!.firstWhereOrNull(
          (e) => e.blockchainType == chain,
        );
        return contract?.address ?? '';
      }
    }
    return null;
  }

  /// Get index ID for indexerTokenId
  /// Returns null if ID is not available
  String? _getIndexId() {
    final chain = series?.exhibition?.mintBlockchain.toLowerCase();
    if (chain == null || chain.isEmpty) {
      return null;
    }

    // if artwork was burned, get token from swap
    if (swap != null) {
      return swap!.token;
    } else {
      // normal case: use artwork ID
      return id;
    }
  }
}

String getFFUrl(String uri, {String? variant}) {
  // case 1: cloudflare
  if (uri.startsWith(cloudFlarePrefix)) {
    final imageVariant = getVariantFromCloudFlareImageUrl(uri);
    if (imageVariant != null) {
      return uri;
    }

    return '$uri/${variant ?? CloudFlareVariant.m.value}';
  }

  // case 2 => full cdn
  if (uri.startsWith('http')) {
    return uri;
  }

  //case 3 => cdn
  return '${Environment.feralFileAssetURL}/$uri';
}

extension FFContractExt on FFContract {
  String? getBlockchainUrl() {
    final network = Environment.appTestnetConfig ? 'TESTNET' : 'MAINNET';
    switch ('${network}_$blockchainType') {
      case 'MAINNET_ethereum':
        return 'https://etherscan.io/address/$address';

      case 'TESTNET_ethereum':
        return 'https://goerli.etherscan.io/address/$address';

      case 'MAINNET_tezos':
      case 'TESTNET_tezos':
        return 'https://tzkt.io/$address';
    }
    return null;
  }
}

extension ArtworkSwapxt on ArtworkSwap {
  String get indexerId {
    final chain = blockchainType == 'ethereum' ? 'eth' : 'tez';
    // we should use token instead of artworkID.
    // the artworkId is the id of burned artwork.
    return '$chain-$contractAddress-$token';
  }
}

enum ExhibitionStatus {
  created,
  editorReview,
  operatorReview,
  issuing,
  issued,
}
