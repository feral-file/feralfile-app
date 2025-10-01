//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/feralfile_api.dart';
import 'package:autonomy_flutter/gateway/source_exhibition_api.dart';
import 'package:autonomy_flutter/model/dailies.dart';
import 'package:autonomy_flutter/model/explore_statistics_data.dart';
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_list_response.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/screen/feralfile_home/filter_bar.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/crawl_helper.dart';
import 'package:autonomy_flutter/util/dailies_helper.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/util/feral_file_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';

enum ArtworkModel {
  multi,
  single,
  multiUnique,
  ;

  String get value {
    switch (this) {
      case ArtworkModel.multi:
        return 'multi';
      case ArtworkModel.single:
        return 'single';
      case ArtworkModel.multiUnique:
        return 'multi_unique';
    }
  }

  String get title {
    switch (this) {
      case ArtworkModel.multiUnique:
        return 'series';
      case ArtworkModel.single:
        return 'single';
      case ArtworkModel.multi:
        return 'edition';
    }
  }

  String get pluralTitle {
    switch (this) {
      case ArtworkModel.multiUnique:
        return 'series';
      case ArtworkModel.single:
        return 'singles';
      case ArtworkModel.multi:
        return 'editions';
    }
  }

  static ArtworkModel? fromString(String value) {
    switch (value) {
      case 'multi':
        return ArtworkModel.multi;
      case 'single':
        return ArtworkModel.single;
      case 'multi_unique':
        return ArtworkModel.multiUnique;
      default:
        return null;
    }
  }
}

enum ExtendedArtworkModel {
  interactiveInstruction,
  ;

  String get title {
    switch (this) {
      case ExtendedArtworkModel.interactiveInstruction:
        return 'interactive instruction';
    }
  }

  String get pluralTitle {
    switch (this) {
      case ExtendedArtworkModel.interactiveInstruction:
        return 'interactive instructions';
    }
  }

  static ExtendedArtworkModel? fromTitle(String title) {
    switch (title) {
      case 'interactive instruction':
        return ExtendedArtworkModel.interactiveInstruction;
      default:
        return null;
    }
  }
}

enum GenerativeMediumTypes {
  software,
  model,
  ;

  String get value {
    switch (this) {
      case GenerativeMediumTypes.software:
        return 'software';
      case GenerativeMediumTypes.model:
        return '3d';
    }
  }
}

abstract class FeralFileService {
  static const int offset = 0;
  static const int limit = 300;

  Future<FFSeries> getSeries(
    String id, {
    String? exhibitionID,
    bool includeFirstArtwork = false,
  });

  Future<List<FFSeries>> getListSeries(
    String exhibitionId, {
    bool includeFirstArtwork = false,
  });

  Future<Exhibition?> getExhibitionFromTokenID(String artworkID);

  Future<FeralFileResaleInfo> getResaleInfo(String exhibitionID);

  Future<String?> getPartnerFullName(String exhibitionId);

  Future<Exhibition> getExhibition(
    String id, {
    bool includeFirstArtwork = false,
  });

  Future<List<Exhibition>> getAllExhibitions({
    String sortBy = 'openAt',
    String sortOrder = 'DESC',
    int limit = 8,
    int offset = 0,
    String keywork = '',
    List<String> relatedAlumniAccountIDs = const [],
    Map<FilterType, FilterValue> filters = const {},
  });

  Future<Exhibition> getSourceExhibition();

  Future<Exhibition?> getUpcomingExhibition();

  Future<Exhibition> getFeaturedExhibition();

  Future<List<Exhibition>> getOngoingExhibitions();

  Future<List<Artwork>> getFeaturedArtworks();

  Future<FeralFileListResponse<Artwork>> getSeriesArtworks(
    String seriesId,
    String exhibitionID, {
    bool withSeries = false,
    int offset = offset,
    int limit = limit,
  });

  Future<Artwork?> getFirstViewableArtwork(String seriesId);

  Future<Artwork> getArtwork(String artworkId);

  Future<Artwork?> getSourceArtwork(String artworkId);

  Future<DailyToken?> getCurrentDailiesToken();

  Future<FeralFileListResponse<FFSeries>> exploreArtworks({
    String? sortBy,
    String? sortOrder,
    String keyword = '',
    int limit = 300,
    int offset = 0,
    bool includeArtist = true,
    bool includeExhibition = true,
    bool includeFirstArtwork = true,
    bool onlyViewable = true,
    List<String> artistIds = const [],
    bool includeUniqeFilePath = true,
    Map<FilterType, FilterValue> filters = const {},
  });

  Future<FeralFileListResponse<AlumniAccount>> getListAlumni({
    int limit = 20,
    int offset = 0,
    bool isArtist = false,
    bool isCurator = false,
    String keywork = '',
    String orderBy = 'relevance',
    String sortOrder = 'DESC',
  });

  Future<AlumniAccount> getAlumniDetail(String alumniID);

  Future<List<Post>> getPosts({
    String sortBy = 'dateTime',
    String sortOrder = '',
    List<String> types = const [],
    List<String> relatedAlumniAccountIDs = const [],
    bool includeExhibition = true,
  });

  Future<ExploreStatisticsData> getExploreStatistics({
    bool unique = true,
    bool excludedFF = true,
  });

  Future<List<String>> getIndexerAssetIdsFromSeries(String seriesId);
}

class FeralFileServiceImpl extends FeralFileService {
  FeralFileServiceImpl(
    this._feralFileApi,
    this._sourceExhibitionAPI,
  );
  final FeralFileApi _feralFileApi;
  final SourceExhibitionAPI _sourceExhibitionAPI;
  Exhibition? sourceExhibition;
  List<BeforeMintingArtworkInfo> beforeMintingArtworkInfos = [];

  @override
  Future<FFSeries> getSeries(
    String id, {
    String? exhibitionID,
    bool includeFirstArtwork = false,
  }) async {
    if (exhibitionID == SOURCE_EXHIBITION_ID) {
      return _getSourceSeries(
        id,
        includeFirstArtwork: includeFirstArtwork,
      );
    }
    final series = (await _feralFileApi.getSeries(
      seriesId: id,
      includeFirstArtwork: includeFirstArtwork,
    ))
        .result;

    if (includeFirstArtwork && series.artwork == null) {
      final exhibition = await getExhibition(series.exhibitionID);
      List<Artwork> artworks = [];
      if (!exhibition.isMinted) {
        final fakeArtworks =
            await _getFakeSeriesArtworks(exhibition, series, 0, 1);
        artworks = fakeArtworks;
      }
      if (artworks.isNotEmpty) {
        return series.copyWith(artwork: artworks.first);
      }
    }

    return series;
  }

  @override
  Future<Exhibition> getExhibition(
    String id, {
    bool includeFirstArtwork = false,
  }) async {
    if (id == SOURCE_EXHIBITION_ID) {
      return getSourceExhibition();
    }
    final resp = await _feralFileApi.getExhibition(
      id,
      includeFirstArtwork: includeFirstArtwork,
    );
    final exhibition = resp.result!;

    if (includeFirstArtwork &&
        exhibition.series != null &&
        exhibition.series!.any((series) => series.artwork == null)) {
      final List<FFSeries> newSeries = [];
      for (final FFSeries series in exhibition.series ?? []) {
        if (!exhibition.isMinted) {
          final seriesDetail = await getSeries(series.id);
          final fakeArtwork =
              await _getFakeSeriesArtworks(exhibition, seriesDetail, 0, 1);
          if (fakeArtwork.isNotEmpty) {
            newSeries.add(series.copyWith(artwork: fakeArtwork.first));
          }
        } else {
          newSeries.add(series);
        }
      }

      return exhibition.copyWith(series: newSeries);
    }

    return exhibition;
  }

  @override
  Future<FeralFileResaleInfo> getResaleInfo(String exhibitionID) async {
    final resaleInfo = await _feralFileApi.getResaleInfo(exhibitionID);
    return resaleInfo.result;
  }

  @override
  Future<String?> getPartnerFullName(String exhibitionId) async {
    final exhibition = await _feralFileApi.getExhibition(exhibitionId);
    return exhibition.result!.partnerAlumni?.fullName;
  }

  @override
  Future<Exhibition?> getExhibitionFromTokenID(String artworkID) async {
    try {
      final artwork = await _feralFileApi.getArtworks(artworkID);
      return getExhibition(artwork.result.series?.exhibitionID ?? '');
    } catch (e) {
      log.info('[FeralFileService] Failed to get exhibition from token ID: $e');
      unawaited(
        Sentry.captureException(
          '[FeralFileService] getExhibitionFromTokenID: $e',
        ),
      );
      return null;
    }
  }

  @override
  Future<List<Exhibition>> getAllExhibitions({
    String sortBy = 'openAt',
    String sortOrder = 'DESC',
    int limit = 8,
    int offset = 0,
    String keywork = '',
    List<String> relatedAlumniAccountIDs = const [],
    Map<FilterType, FilterValue> filters = const {},
  }) async {
    final customParams =
        filters.map((key, value) => MapEntry(key.queryParam, value.queryParam));
    final exhibitions = await _feralFileApi.getAllExhibitions(
      sortBy: sortBy,
      sortOrder: sortOrder,
      limit: limit,
      offset: offset,
      keyword: keywork,
      relatedAlumniAccountIDs: relatedAlumniAccountIDs,
      customQueryParam: customParams,
    );
    final listExhibition = exhibitions.result;
    log
      ..info('[FeralFileService] Get all exhibitions: ${listExhibition.length}')
      ..info('[FeralFileService] Get all exhibitions: '
          '${listExhibition.map((e) => e.id).toList()}');
    return listExhibition;
  }

  @override
  Future<Exhibition?> getUpcomingExhibition() async {
    final exhibitionResponse = await _feralFileApi.getUpcomingExhibition();
    return exhibitionResponse.result;
  }

  @override
  Future<Exhibition> getFeaturedExhibition() async {
    final exhibitionResponse = await _feralFileApi.getFeaturedExhibition();
    return exhibitionResponse.result!;
  }

  @override
  Future<List<Exhibition>> getOngoingExhibitions() async {
    final ongoingExhibitionIDs = FeralFileHelper.ongoingExhibitionIDs;

    final ongoingExhibitions = <Exhibition>[];
    for (final exhibitionID in ongoingExhibitionIDs) {
      try {
        final exhibition = await getExhibition(exhibitionID);
        ongoingExhibitions.add(exhibition);
      } catch (e) {
        log.info('[FeralFileService] Failed to get ongoing exhibition: $e');
      }
    }

    return ongoingExhibitions;
  }

  @override
  Future<List<Artwork>> getFeaturedArtworks() async {
    final response = await _feralFileApi.getFeaturedArtworks();
    return response.result;
  }

  Future<List<Artwork>> _getFakeSeriesArtworks(
    Exhibition exhibition,
    FFSeries series,
    int offset,
    int limit,
  ) async {
    if (!series.shouldFakeArtwork) {
      return [];
    }
    if (exhibition.isJohnGerrardShow) {
      return _getJohnGerrardFakeArtworks(
        series: series,
        offset: offset,
        limit: limit,
        onlySignedArtwork: true,
      );
    }
    final fakeArtworks =
        _createFakeSeriesArtworks(series, exhibition, offset, limit);
    return fakeArtworks;
  }

  Future<List<Artwork>> _createFakeSeriesArtworks(
    FFSeries series,
    Exhibition exhibition,
    int offset,
    int limit,
  ) async {
    final List<Artwork> artworks = [];
    final maxArtworks =
        min(offset + limit, series.settings?.maxArtwork ?? offset + limit);
    for (var i = offset; i < maxArtworks; i++) {
      final previewURI = await _getPreviewURI(series, i, exhibition);
      final artworkId = getFeralfileTokenId(
        seriesOnchainID: series.onchainID ?? '',
        exhibitionID: series.exhibitionID,
        artworkIndex: i,
      );
      final thumbnailURI = _getThumbnailURI(series, i);
      final fakeArtwork = Artwork(
        artworkId,
        series.id,
        i,
        '#${i + 1}',
        'Artwork category $i',
        'ownerAccountID',
        null,
        null,
        'blockchainStatus',
        false,
        thumbnailURI,
        null,
        previewURI ?? '',
        {},
        {},
        DateTime.now(),
        DateTime.now(),
        DateTime.now(),
        null,
        series,
        null,
        null,
      );
      artworks.add(fakeArtwork);
    }
    return artworks;
  }

  String getFeralfileTokenId({
    required String seriesOnchainID,
    required String exhibitionID,
    required int artworkIndex,
  }) {
    final BigInt si = BigInt.parse(seriesOnchainID);
    final BigInt msi = si * BigInt.from(1000000) + BigInt.from(artworkIndex);
    final String part1 = exhibitionID.replaceAll('-', '');
    // padding with 0 to 32 characters
    final String part2 = msi.toRadixString(16).padLeft(32, '0');
    final String p = part1 + part2;
    final BigInt tokenIDBigInt = BigInt.parse('0x$p');
    final String tokenID = tokenIDBigInt.toString();
    return tokenID;
  }

  Future<String> previewArtCustomTokenID({
    required String seriesOnchainID,
    required String exhibitionID,
    required int artworkIndex,
  }) async {
    final String tokenID = getFeralfileTokenId(
      seriesOnchainID: seriesOnchainID,
      exhibitionID: exhibitionID,
      artworkIndex: artworkIndex,
    );
    final Uint8List tokenIDBytes = utf8.encode(tokenID);
    final String tokenIDHash = sha256.convert(tokenIDBytes).toString();
    return '&token_id=$tokenID&token_id_hash=0x$tokenIDHash';
  }

  Future<String?> _getPreviewURI(
    FFSeries series,
    int artworkIndex,
    Exhibition exhibition,
  ) async {
    String? previewURI;
    if (!series.isMultiUnique) {
      previewURI = getFFUrl(series.previewFile?.uri ?? '');
    } else {
      if (exhibition.isCrawlShow) {
        // if crawl show, use the unique preview path with "/"
        previewURI = '${series.uniquePreviewPath}/$artworkIndex';
        previewURI += '/';
      } else {
        // normal case
        if (series.isGenerative) {
          previewURI ??= getFFUrl(series.previewFile?.uri ?? '');
          final artworkNumber = artworkIndex + 1;
          previewURI = '$previewURI?'
              '&artwork_number=$artworkNumber'
              '&blockchain=${exhibition.mintBlockchain}';
          try {
            final tokenParameters = await previewArtCustomTokenID(
              seriesOnchainID: series.onchainID ?? '',
              exhibitionID: series.exhibitionID,
              artworkIndex: artworkIndex,
            );
            previewURI += tokenParameters;
          } catch (error, stackTrace) {
            log.info('[FeralFileService] '
                'Get preview URI failed: $error, $stackTrace');
          }
        } else {
          previewURI = '${series.uniquePreviewPath}/$artworkIndex';
        }
      }
    }
    return previewURI;
  }

  String _getThumbnailURI(FFSeries series, int artworkIndex) =>
      series.uniqueThumbnailPath != null
          ? '${series.uniqueThumbnailPath}/$artworkIndex-large.jpg'
          : series.thumbnailURI ?? '';

  Future<FeralFileListResponse<Artwork>> _fakeSeriesArtworks(
    String seriesId,
    Exhibition exhibition, {
    required int offset,
    required int limit,
  }) async {
    final series = await getSeries(seriesId);
    final List<Artwork> seriesArtworks =
        await _getFakeSeriesArtworks(exhibition, series, offset, limit);
    final total = series.latestRevealedArtworkIndex == null
        ? series.maxEdition
        : series.latestRevealedArtworkIndex! + 1;
    return FeralFileListResponse(
      result: seriesArtworks,
      paging: Paging(offset: offset, limit: limit, total: total),
    );
  }

  @override
  Future<FeralFileListResponse<Artwork>> getSeriesArtworks(
    String seriesId,
    String exhibitionID, {
    bool withSeries = false,
    int offset = FeralFileService.offset,
    int limit = FeralFileService.limit,
  }) async {
    if (exhibitionID == SOURCE_EXHIBITION_ID) {
      final artworks = await _getSourceSeriesArtworks(seriesId);
      return FeralFileListResponse(
        result: artworks.sublist(offset, min(artworks.length, offset + limit)),
        paging: Paging(offset: 0, limit: limit, total: artworks.length),
      );
    }
    final exhibition = await getExhibition(exhibitionID);

    if (!exhibition.isMinted) {
      return _fakeSeriesArtworks(
        seriesId,
        exhibition,
        offset: offset,
        limit: limit,
      );
    }

    final FeralFileListResponse<Artwork> artworksResponse;
    if (seriesId == CrawlHelper.mergeSeriesID) {
      artworksResponse = await _feralFileApi.getListArtworks(
        seriesId: seriesId,
        offset: offset,
        limit: limit,
        sortOrder: 'DESC',
        filterBurned: true,
      );
    } else {
      artworksResponse = await _feralFileApi.getListArtworks(
        seriesId: seriesId,
        offset: offset,
        limit: limit,
      );
    }

    if (withSeries) {
      final series = await getSeries(seriesId);
      artworksResponse.copyWith(
        result: artworksResponse.result
            .map((e) => e.copyWith(series: series))
            .toList(),
      );
    }
    log
      ..info(
        '[FeralFileService] Get series artworks:'
        ' ${artworksResponse.result.length}, offset $offset, limit $limit',
      )
      ..info(
        '[FeralFileService] Get series artworks: '
        '${artworksResponse.result.map((e) => e.id).toList()}',
      );
    return artworksResponse;
  }

  @override
  Future<Artwork?> getFirstViewableArtwork(String seriesId) async {
    final response = await _feralFileApi.getListArtworks(
      seriesId: seriesId,
      includeActiveSwap: false,
      sortOrder: 'DESC',
      isViewable: true,
    );
    return response.result.firstOrNull;
  }

  @override
  Future<Artwork> getArtwork(String artworkId) async {
    final response = await _feralFileApi.getArtworks(artworkId);
    return response.result;
  }

  @override
  Future<Artwork?> getSourceArtwork(String artworkId) async {
    sourceExhibition ??= await getSourceExhibition();
    if (sourceExhibition == null) {
      throw Exception('Source exhibition is not available');
    }

    if (sourceExhibition!.series == null) {
      final series = await _sourceExhibitionAPI.getSourceExhibitionSeries();
      sourceExhibition = sourceExhibition!.copyWith(series: series);
    }
    final response = sourceExhibition!.series
        ?.firstWhereOrNull(
          (series) =>
              series.artworks?.any((artwork) => artwork.id == artworkId) ??
              false,
        )
        ?.artworks
        ?.firstWhereOrNull(
          (artwork) => artwork.id == artworkId,
        );
    return response;
  }

  @override
  Future<List<FFSeries>> getListSeries(
    String exhibitionId, {
    bool includeFirstArtwork = false,
  }) async {
    if (exhibitionId == SOURCE_EXHIBITION_ID) {
      final exhibition = await getSourceExhibition();
      return exhibition.series ?? [];
    }
    final response = await _feralFileApi.getListSeries(
      exhibitionID: exhibitionId,
      sortBy: 'displayIndex',
      sortOrder: 'ASC',
    );
    return response.result;
  }

  @override
  Future<List<Post>> getPosts({
    String sortBy = 'dateTime',
    String sortOrder = 'DESC',
    List<String> types = const [],
    List<String> relatedAlumniAccountIDs = const [],
    bool includeExhibition = true,
  }) async {
    final response = await _feralFileApi.getPosts(
      sortBy: sortBy,
      sortOrder: sortOrder,
      types: types,
      relatedAlumniAccountIDs: relatedAlumniAccountIDs,
      includeExhibition: includeExhibition,
    );
    return response.result;
  }

  // Source Exhibition
  @override
  Future<Exhibition> getSourceExhibition() async {
    if (sourceExhibition != null) {
      return sourceExhibition!;
    }

    final exhibition = await _sourceExhibitionAPI.getSourceExhibitionInfo();
    final series = await _sourceExhibitionAPI.getSourceExhibitionSeries();
    final seriesWithExhibition = series.map((s) {
      // Ensure each series has the exhibition reference
      return s.copyWith(exhibition: exhibition);
    }).toList();
    sourceExhibition = exhibition.copyWith(series: seriesWithExhibition);
    return sourceExhibition!;
  }

  Future<FFSeries> _getSourceSeries(
    String seriesID, {
    bool includeFirstArtwork = false,
  }) async {
    late List<FFSeries> listSeries;
    if (sourceExhibition != null && sourceExhibition!.series != null) {
      listSeries = sourceExhibition!.series!;
    } else {
      listSeries = await _sourceExhibitionAPI.getSourceExhibitionSeries();
    }

    final series = listSeries
        .firstWhere((series) => series.id == seriesID)
        .copyWith(exhibition: sourceExhibition);
    if (includeFirstArtwork) {
      final firstArtwork = series.artworks!.first;
      return series.copyWith(artwork: firstArtwork);
    }

    return series;
  }

  Future<List<Artwork>> _getSourceSeriesArtworks(String seriesID) async {
    final series = await _getSourceSeries(seriesID);
    return series.artworks!;
  }

  // John Gerrard exhibition
  Future<List<BeforeMintingArtworkInfo>> _getBeforeMintingArtworkInfos(
    FFSeries series,
  ) async {
    if (beforeMintingArtworkInfos.isNotEmpty) {
      return beforeMintingArtworkInfos;
    }

    try {
      final artworkInfoLink =
          '${Environment.feralFileAssetURL}/previews/${series.id}/${series.previewFile?.version ?? ''}/info.json';
      final response = await http.get(Uri.parse(artworkInfoLink));
      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        beforeMintingArtworkInfos = body.entries.map((entry) {
          final map = entry.value as Map<String, dynamic>;
          return BeforeMintingArtworkInfo.fromJson(map);
        }).toList();
        return beforeMintingArtworkInfos;
      } else {
        throw Exception('Failed to load SOURCE series');
      }
    } catch (e) {
      throw Exception('Failed to load SOURCE series');
    }
  }

  Future<List<Artwork>> _getJohnGerrardFakeArtworks({
    required FFSeries series,
    required int offset,
    bool onlySignedArtwork = false,
    int limit = 50,
  }) async {
    int maxArtwork;
    if (onlySignedArtwork) {
      maxArtwork = series.latestRevealedArtworkIndex == null
          ? 0
          : (series.latestRevealedArtworkIndex! + 1);
    } else {
      maxArtwork = series.settings?.maxArtwork ?? 0;
    }

    if (maxArtwork == 0) {
      return [];
    }

    final endIndex = min(offset + limit, maxArtwork);
    if (offset >= endIndex) {
      return [];
    }

    final List<Artwork> fakeArtworks = [];
    for (var index = offset; index < endIndex; index++) {
      final fakeArtwork = await _getJohnGerrardArtworkByIndex(index, series);
      fakeArtworks.add(fakeArtwork);
    }

    return fakeArtworks;
  }

  Future<Artwork> _getJohnGerrardArtworkByIndex(
    int index,
    FFSeries series,
  ) async {
    final beforeMintingArtworkInfos =
        await _getBeforeMintingArtworkInfos(series);
    final artworkId = getFeralfileTokenId(
      seriesOnchainID: series.onchainID ?? '',
      exhibitionID: series.exhibitionID,
      artworkIndex: index,
    );
    return Artwork(
      artworkId,
      series.id,
      index,
      beforeMintingArtworkInfos[index].artworkTitle,
      '',
      null,
      null,
      null,
      '',
      false,
      'previews/${series.id}/${series.previewFile?.version}/generated_images/crystal_${index + MAGIC_NUMBER}_img.jpg',
      null,
      'previews/${series.id}/${series.previewFile?.version}/nft.html?hourIdx=${index + MAGIC_NUMBER}',
      {},
      {
        'viewableAt': beforeMintingArtworkInfos[index].viewableAt,
      },
      DateTime.now(),
      DateTime.now(),
      DateTime.now(),
      null,
      series,
      null,
      null,
    );
  }

  Future<List<DailyToken>> _fetchDailiesTokens() async {
    final currentDailyTokens = await _fetchDailyTokenByDate(DateTime.now());
    if (currentDailyTokens.isEmpty) {
      unawaited(Sentry.captureMessage('Failed to get current daily token'));
      return [];
    }
    DailiesHelper.updateDailies([currentDailyTokens.first]);
    return currentDailyTokens;
  }

  Future<List<DailyToken>> _fetchDailyTokenByDate(DateTime localTime) async {
    const defaultScheduleTime = 6;
    final configScheduleTime =
        injector<RemoteConfigService>().getConfig<String>(
      ConfigGroup.daily,
      ConfigKey.scheduleTime,
      defaultScheduleTime.toString(),
    );

    // the daily artwork change at configScheduleTime
    // so we will subtract configScheduleTime hours to get the correct date
    final date =
        localTime.subtract(Duration(hours: int.parse(configScheduleTime)));
    final dateFormatter = DateFormat('yyyy-MM-dd');

    final resp = await _feralFileApi.getDailiesTokenByDate(
      date: dateFormatter.format(date),
    );
    final dailiesTokens = resp.result;
    return dailiesTokens;
  }

  @override
  Future<DailyToken?> getCurrentDailiesToken() async {
    // call nextDailies to make daily tokens up to date
    await _fetchDailiesTokens();
    final DailyToken? currentDailiesToken = DailiesHelper.currentDailies;
    return currentDailiesToken;
  }

  @override
  Future<FeralFileListResponse<FFSeries>> exploreArtworks({
    String? sortBy,
    String? sortOrder,
    String keyword = '',
    int limit = 300,
    int offset = 0,
    bool includeArtist = true,
    bool includeExhibition = true,
    bool includeFirstArtwork = true,
    bool onlyViewable = true,
    List<String> artistIds = const [],
    bool includeUniqeFilePath = true,
    Map<FilterType, FilterValue> filters = const {},
  }) async {
    final Map<String, String> customParams = {};
    for (final entry in filters.entries) {
      final key = entry.key;
      final value = entry.value;
      customParams.addAll({key.queryParam: value.queryParam});
    }
    final res = await _feralFileApi.exploreArtwork(
      sortBy: sortBy,
      sortOrder: sortOrder,
      keyword: keyword,
      limit: limit,
      offset: offset,
      includeArtist: includeArtist,
      includeExhibition: includeExhibition,
      includeFirstArtwork: includeFirstArtwork,
      onlyViewable: onlyViewable,
      artistAlumniAccountIDs: artistIds,
      includeUniqueFilePath: includeUniqeFilePath,
      customQueryParam: customParams,
    );
    log.info('[FeralFileService] Explore artworks with keyword: $keyword');
    return res;
  }

  @override
  Future<FeralFileListResponse<AlumniAccount>> getListAlumni({
    int limit = 20,
    int offset = 0,
    bool isArtist = false,
    bool isCurator = false,
    String keywork = '',
    String orderBy = 'relevance',
    String sortOrder = 'DESC',
  }) async {
    final res = await _feralFileApi.getListAlumni(
      limit: limit,
      offset: offset,
      isArtist: isArtist,
      isCurator: isCurator,
      keyword: keywork,
      sortOrder: sortOrder,
      sortBy: orderBy,
    );
    return res;
  }

  @override
  Future<AlumniAccount> getAlumniDetail(String alumniID) async {
    final res = await _feralFileApi.getAlumni(alumniID: alumniID);
    return res.result;
  }

  @override
  Future<ExploreStatisticsData> getExploreStatistics({
    bool unique = true,
    bool excludedFF = true,
  }) async {
    final res = await _feralFileApi.getExploreStatistics(
      unique: unique,
      excludedFF: excludedFF,
    );
    return res;
  }

  @override
  Future<List<String>> getIndexerAssetIdsFromSeries(String seriesId) async {
    final res = await _feralFileApi.getIndexerAssetIds(seriesId: seriesId);
    return res;
  }
}
