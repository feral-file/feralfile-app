//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/service/custom_meilisearch_sdk.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/util/dio_interceptors.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/timer_metric.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:meilisearch/meilisearch.dart';

/// Service for searching across multiple MeiliSearch indexes using the official MeiliSearch SDK
class MeiliSearchService {
  MeiliSearchService._internal({this.prefix = 'ffprod'});

  /// Create a new instance with the specified prefix
  factory MeiliSearchService({String prefix = 'ffprod'}) =>
      MeiliSearchService._internal(prefix: prefix);

  late final MeiliSearchClient _client;
  final String prefix;

  late CustomMeiliSDK _customClient;

  /// Initialize the service with MeiliSearch configuration
  void initialize() {
    _customClient = CustomMeiliSDK(prefix: prefix)..initialize();
    final ioAdapter = IOHttpClientAdapter();
    ioAdapter.createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 90);
      client.connectionTimeout = const Duration(seconds: 5);
      client.maxConnectionsPerHost = 6;
      return client;
    };

    final interceptors = <Interceptor>[
      // Existing MeiliSearch timing/logging interceptor
      MeiliSearchInterceptor(),
      // Ensure gzip and any future per-request headers
      InterceptorsWrapper(onRequest: (options, handler) {
        options.headers['Accept-Encoding'] = 'gzip';
        options.headers['Connection'] = 'keep-alive';
        handler.next(options);
      }),
    ];

    _client = MeiliSearchClient.withCustomDio(
      Environment.meiliSearchUrl,
      apiKey: Environment.meiliSearchKey,
      connectTimeout: const Duration(seconds: 5),
      adapter: ioAdapter,
      interceptors: interceptors,
    );

    // Warm-up connection to reduce first-request latency
    unawaited(_client.health());
  }

  /// Search across all indexes (artworks, exhibitions, artists, curators, series)
  Future<MeiliSearchResult> searchAll({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final start = DateTime.now();

    // final res = await _customClient.searchAll(
    //   query: text,
    //   limit: limit,
    //   offset: offset,
    //   filters: filters,
    // );
    //
    // final duration = DateTime.now().difference(start);
    // log.info(
    //     'MeiliSearchService.searchAll took $duration ms with total hits: ${res.totalHits}');
    //
    // return res;

    // Build multi index query
    final queries = [
      IndexSearchQuery(
        indexUid: '${prefix}_artworks',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
      IndexSearchQuery(
        indexUid: '${prefix}_exhibitions',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
      IndexSearchQuery(
        indexUid: '${prefix}_artists',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
      IndexSearchQuery(
        indexUid: '${prefix}_curators',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
      IndexSearchQuery(
        indexUid: '${prefix}_series',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
    ];

    final multiResult = await timerMetric(
        'Meili Multi Search for $text',
        () async =>
            await _client.multiSearch(MultiSearchQuery(queries: queries)));

    // Parse results in index order and extract ranking scores
    final artworksRaw = multiResult.results[0].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final artworks = artworksRaw
        .map((map) =>
            Artwork.fromJson(Map<String, dynamic>.from(map['artwork'] as Map)))
        .toList();
    final artworksRankingScore = artworksRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final exhibitionsRaw = multiResult.results[1].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final exhibitions = exhibitionsRaw
        .map((map) => Exhibition.fromJson(
            Map<String, dynamic>.from(map['exhibition'] as Map)))
        .toList();
    final exhibitionsRankingScore = exhibitionsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final artistsRaw = multiResult.results[2].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final artists = artistsRaw
        .map((map) => AlumniAccount.fromJson(
            Map<String, dynamic>.from(map['artist'] as Map)))
        .toList();
    final artistsRankingScore = artistsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final curatorsRaw = multiResult.results[3].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final curators = curatorsRaw
        .map((map) => AlumniAccount.fromJson(
            Map<String, dynamic>.from(map['curator'] as Map)))
        .toList();
    final curatorsRankingScore = curatorsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final seriesRaw = multiResult.results[4].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final series = seriesRaw
        .map((map) =>
            FFSeries.fromJson(Map<String, dynamic>.from(map['series'] as Map)))
        .toList();
    final seriesRankingScore = seriesRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final result = MeiliSearchResult(
      artworks: artworks,
      exhibitions: exhibitions,
      artists: artists,
      curators: curators,
      series: series,
      artworksRankingScore: artworksRankingScore,
      exhibitionsRankingScore: exhibitionsRankingScore,
      artistsRankingScore: artistsRankingScore,
      curatorsRankingScore: curatorsRankingScore,
      seriesRankingScore: seriesRankingScore,
      totalHits: artworks.length +
          exhibitions.length +
          artists.length +
          curators.length +
          series.length,
      processingTimeMs: multiResult.results
          .fold(0, (sum, result) => sum + (result.processingTimeMs ?? 0)),
    );
    log.info(
        'MeiliSearchService.searchAll processing time: ${result.processingTimeMs} ms');
    log.info(
        'MeiliSearchService.searchAll processing time of each index: ${multiResult.results.map((result) => result.processingTimeMs).toList()}');
    log.info(
        'MeiliSearchService.searchAll completed in ${DateTime.now().difference(start).inMilliseconds} ms with total hits: ${result.totalHits}');
    return result;
  }

  /// Helper method to safely execute a search and return null if it fails
  Future<T?> _safeSearch<T>(Future<T> Function() searchFunction) async {
    try {
      return await searchFunction();
    } catch (e) {
      log.warning('Search failed: $e');
      return null;
    }
  }

  Future<Searcheable<Map<String, dynamic>>> _search(
      String text, String suffix, SearchQuery query) async {
    final indexName = '${prefix}_$suffix';
    final idx = _client.index(indexName);
    final res = await timerMetric(
        'Meili Search $indexName', () async => idx.search(text, query));
    return res;
  }

  /// Search artworks only
  Future<List<Artwork>> searchArtworks({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'artworks';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
      // filter: filters?.join(' AND '),
      // sort: ['created_at:desc'],
      // attributesToRetrieve: ['id', 'title', 'artist', 'image_url'],
      // attributesToSearchOn: ['title', 'artist', 'image_url'],
      // showRankingScore: true,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final artworkJson =
            Map<String, dynamic>.from(hit as Map)['artwork'] as Map;
        return Artwork.fromJson(Map<String, dynamic>.from(artworkJson));
      } catch (e) {
        log.warning('Failed to parse artwork: $e');
        rethrow;
      }
    }).toList();
  }

  /// Search exhibitions only
  Future<List<Exhibition>> searchExhibitions({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'exhibitions';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
      // filter: filters?.join(' AND '),
      // sort: ['created_at:desc'],
      // attributesToRetrieve: ['id', 'title', 'artist', 'image_url'],
      // attributesToSearchOn: ['title', 'artist', 'image_url'],
      // showRankingScore: true,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final exhibitionJson =
            Map<String, dynamic>.from(hit as Map)['exhibition'] as Map;
        return Exhibition.fromJson(Map<String, dynamic>.from(exhibitionJson));
      } catch (e) {
        log.warning('Failed to parse exhibition: $e');
        rethrow;
      }
    }).toList();
  }

  /// Search artists only
  Future<List<AlumniAccount>> searchArtists({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'artists';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
      // filter: filters?.join(' AND '),
      // sort: ['created_at:desc'],
      // attributesToRetrieve: ['id', 'title', 'artist', 'image_url'],
      // attributesToSearchOn: ['title', 'artist', 'image_url'],
      // showRankingScore: true,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final artistJson =
            Map<String, dynamic>.from(hit as Map)['artist'] as Map;
        return AlumniAccount.fromJson(Map<String, dynamic>.from(artistJson));
      } catch (e) {
        log.warning('Failed to parse artist: $e');
        rethrow;
      }
    }).toList();
  }

  /// Search curators only
  Future<List<AlumniAccount>> searchCurators({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'curators';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
      // filter: filters?.join(' AND '),
      // sort: ['created_at:desc'],
      // attributesToRetrieve: ['id', 'title', 'artist', 'image_url'],
      // attributesToSearchOn: ['title', 'artist', 'image_url'],
      // showRankingScore: true,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final curatorJson =
            Map<String, dynamic>.from(hit as Map)['curator'] as Map;
        return AlumniAccount.fromJson(Map<String, dynamic>.from(curatorJson));
      } catch (e) {
        log.warning('Failed to parse curator: $e');
        rethrow;
      }
    }).toList();
  }

  /// Search series only
  Future<List<FFSeries>> searchSeries({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'series';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
      // filter: filters?.join(' AND '),
      // sort: ['created_at:desc'],
      // attributesToRetrieve: ['id', 'title', 'artist', 'image_url'],
      // attributesToSearchOn: ['title', 'artist', 'image_url'],
      // showRankingScore: true,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final seriesJson =
            Map<String, dynamic>.from(hit as Map)['series'] as Map;
        return FFSeries.fromJson(Map<String, dynamic>.from(seriesJson));
      } catch (e) {
        log.warning('Failed to parse series: $e');
        rethrow;
      }
    }).toList();
  }
}

/// Result class for MeiliSearch operations
// MeiliSearchResult moved to meilisearch_models.dart
