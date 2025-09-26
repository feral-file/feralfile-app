//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/dailies.dart';
import 'package:autonomy_flutter/model/explore_statistics_data.dart';
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_list_response.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'feralfile_api.g.dart';

@RestApi(baseUrl: '')
abstract class FeralFileApi {
  factory FeralFileApi(Dio dio, {String baseUrl}) = _FeralFileApi;

  @GET('/api/exhibitions/{exhibitionId}')
  Future<ExhibitionResponse> getExhibition(
      @Path('exhibitionId') String exhibitionId,
      {@Query('includeFirstArtwork') bool includeFirstArtwork = false});

  @GET('/api/series/{seriesId}')
  Future<FFSeriesResponse> getSeries({
    @Path('seriesId') required String seriesId,
    @Query('includeFiles') bool includeFiles = true,
    @Query('includeCollectibility') bool includeCollectibility = true,
    @Query('includeUniqueFilePath') bool includeUniqueFilePath = true,
    @Query('includeFirstArtwork') bool includeFirstArtwork = true,
  });

  @GET('/api/series')
  Future<FFListSeriesResponse> getListSeries({
    @Query('exhibitionID') required String exhibitionID,
    @Query('sortBy') String? sortBy,
    @Query('sortOrder') String? sortOrder,
    @Query('includeArtist') bool includeArtist = true,
    @Query('includeUniqueFilePath') bool includeUniqueFilePath = true,
  });

  @GET('/api/exhibitions/{exhibitionID}/revenue-setting/resale')
  Future<ResaleResponse> getResaleInfo(
      @Path('exhibitionID') String exhibitionID);

  @GET('/api/artworks/{tokenID}')
  Future<ArtworkResponse> getArtworks(
    @Path('tokenID') String tokenID, {
    @Query('includeSeries') bool includeSeries = true,
    @Query('includeExhibition') bool includeExhibition = true,
    @Query('includeArtist') bool includeArtist = true,
  });

  @GET('/api/exhibitions')
  Future<ListExhibitionResponse> getAllExhibitions({
    @Query('sortBy') String? sortBy,
    @Query('sortOrder') String? sortOrder,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
    @Query('keyword') String? keyword,
    @Query('relatedAlumniAccountIDs')
    List<String> relatedAlumniAccountIDs = const [],
    @Query('customQueryParams')
    Map<String, dynamic> customQueryParam = const {},
  });

  @GET('/api/exhibitions/featured')
  Future<ExhibitionResponse> getFeaturedExhibition();

  @GET('/api/artworks/featured')
  Future<FFListArtworksResponse> getFeaturedArtworks({
    @Query('includeArtist') bool includeArtist = true,
    @Query('includeExhibition') bool includeExhibition = true,
    @Query('includeExhibitionContract') bool includeExhibitionContract = true,
    @Query('includeSuccessfulSwap') bool includeSuccessfulSwap = true,
  });

  @GET('/api/exhibitions/upcoming')
  Future<ExhibitionResponse> getUpcomingExhibition();

  @GET('/api/artworks')
  Future<FeralFileListResponse<Artwork>> getListArtworks({
    @Query('exhibitionID') String? exhibitionId,
    @Query('seriesID') String? seriesId,
    @Query('offset') int? offset = 0,
    @Query('limit') int? limit = 1,
    @Query('includeActiveSwap') bool includeActiveSwap = true,
    @Query('sortBy') String sortBy = 'index',
    @Query('sortOrder') String sortOrder = 'ASC',
    @Query('isViewable') bool? isViewable,
    @Query('filterBurned') bool? filterBurned,
  });

  // get list daily token by date with local time
  @GET('/api/dailies/date/{date}')
  Future<FeralFileListResponse<DailyToken>> getDailiesTokenByDate({
    @Path('date') required String date,
    @Query('includeSuccessfulSwap') bool? includeSuccessfulSwap = true,
  });

  @GET('/api/series')
  Future<FeralFileListResponse<FFSeries>> exploreArtwork({
    @Query('sortBy') String? sortBy,
    @Query('sortOrder') String? sortOrder,
    @Query('limit') int limit = 20,
    @Query('offset') int offset = 0,
    @Query('includeArtist') bool includeArtist = true,
    @Query('includeExhibition') bool includeExhibition = true,
    @Query('includeFirstArtwork') bool includeFirstArtwork = true,
    @Query('onlyViewable') bool onlyViewable = true,
    @Query('keyword') String keyword = '',
    @Query('artistAlumniAccountIDs')
    List<String> artistAlumniAccountIDs = const [],
    @Query('includeUniqueFilePath') bool includeUniqueFilePath = true,
    // custom query params
    @Query('customQueryParams')
    Map<String, dynamic> customQueryParam = const {},
  });

  @GET('/api/alumni')
  Future<FeralFileListResponse<AlumniAccount>> getListAlumni({
    @Query('limit') int limit = 20,
    @Query('offset') int offset = 0,
    @Query('sortBy') String sortBy = 'relevance',
    @Query('sortOrder') String sortOrder = 'DESC',
    @Query('keyword') String keyword = '',
    @Query('isArtist') bool isArtist = false,
    @Query('isCurator') bool isCurator = false,
    @Query('unique') bool unique = true,
    @Query('excludedFF') bool excludedFF = true,
  });

  @GET('/api/exploration/statistics')
  Future<ExploreStatisticsData> getExploreStatistics({
    @Query('unique') bool unique = true,
    @Query('excludedFF') bool excludedFF = true,
  });

  @GET('/api/alumni/{alumniId}')
  Future<FeralFileResponse<AlumniAccount>> getAlumni({
    @Path('alumniId') String alumniID = '',
    @Query('includeCollaborationAlumniAccounts')
    bool includeCollaborationAlumniAccounts = true,
  });

  @GET('/api/posts')
  Future<FeralFileListResponse<Post>> getPosts({
    @Query('sortBy') String sortBy = 'dateTime',
    @Query('sortOrder') String sortOrder = 'DESC',
    @Query('types') List<String> types = const [],
    @Query('relatedAlumniAccountIDs')
    List<String> relatedAlumniAccountIDs = const [],
    @Query('includeExhibition') bool includeExhibition = true,
  });

  //api/series/3d56be3c-fa55-4a0d-8a36-f3ea1a1f0bb3/indexer-asset-ids
  @GET('/api/series/{seriesId}/indexer-asset-ids')
  Future<List<String>> getIndexerAssetIds({
    @Path('seriesId') required String seriesId,
  });
}

class ActionMessageResponse {
  String message;

  ActionMessageResponse({required this.message});

  factory ActionMessageResponse.fromJson(Map<String, dynamic> json) =>
      ActionMessageResponse(
        message: (json['result']['message'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'result': {'message': message},
      };
}

class FFListSeriesResponse {
  List<FFSeries> result;

  FFListSeriesResponse({required this.result});

  factory FFListSeriesResponse.fromJson(Map<String, dynamic> json) =>
      FFListSeriesResponse(
        result: (json['result'] as List<dynamic>)
            .map((e) => FFSeries.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'result': result,
      };
}

class FFListArtworksResponse {
  List<Artwork> result;

  FFListArtworksResponse({required this.result});

  factory FFListArtworksResponse.fromJson(Map<String, dynamic> json) =>
      FFListArtworksResponse(
        result: (json['result'] as List<dynamic>)
            .map((e) => Artwork.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'result': result,
      };
}

class FeralFileResponse<T> {
  T result;

  FeralFileResponse({required this.result});

  factory FeralFileResponse.fromJson(Map<String, dynamic> json,
          {T Function(Map<String, dynamic>)? fromJson}) =>
      FeralFileResponse(
        result: fromJson != null
            ? fromJson(json['result'] as Map<String, dynamic>)
            : json['result'] as T,
      );

  Map<String, dynamic> toJson() => {
        'result': result,
      };
}
