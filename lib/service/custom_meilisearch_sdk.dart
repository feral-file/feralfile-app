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
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:meilisearch/meilisearch.dart';

/// Custom MeiliSearch service using Dio for HTTP requests
class CustomMeiliSDK {
  CustomMeiliSDK._internal({this.prefix = 'ffprod'});

  /// Create a new instance with the specified prefix
  factory CustomMeiliSDK({String prefix = 'ffprod'}) =>
      CustomMeiliSDK._internal(prefix: prefix);

  late final Dio _dio;
  final String prefix;

  /// Initialize the service with MeiliSearch configuration
  void initialize() {
    _dio = DioManager().base(BaseOptions(
      baseUrl: Environment.meiliSearchUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer ${Environment.meiliSearchKey}',
        'Content-Type': 'application/json',
        'Accept-Encoding': 'gzip',
      },
    ));

    // Configure IO adapter with tuned HttpClient for better connection reuse
    final ioAdapter = IOHttpClientAdapter();
    ioAdapter.createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 90);
      client.connectionTimeout = const Duration(seconds: 5);
      client.maxConnectionsPerHost = 6;
      return client;
    };
    _dio.httpClientAdapter = ioAdapter;

    // Ensure gzip header stays present even if caller overrides headers
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      options.headers['Accept-Encoding'] = 'gzip';
      handler.next(options);
    }));

    // Warm-up to reduce cold-start latency (ignore errors)
    unawaited(_dio
        .get<Map<String, dynamic>>('/health')
        .then((_) {}, onError: (_) {}));
  }

  /// Multi-search across multiple indexes in a single request
  Future<MultiSearchResult> multiSearch(MultiSearchQuery query) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/multi-search',
      data: query.toSparseMap(),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, Object?>;
      return MultiSearchResult.fromMap(data);
    } else {
      throw Exception('MeiliSearch API error: ${response.statusCode}');
    }
  }

  /// Search across all indexes (artworks, exhibitions, artists, curators, series)
  Future<MeiliSearchResult> searchAll({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    // Execute per-index search calls in parallel to collect items and ranking scores
    final searchFutures = [
      _safeSearch(() =>
          _searchIndex('${prefix}_artworks', query, limit, offset, filters)),
      _safeSearch(() =>
          _searchIndex('${prefix}_exhibitions', query, limit, offset, filters)),
      _safeSearch(() =>
          _searchIndex('${prefix}_artists', query, limit, offset, filters)),
      _safeSearch(() =>
          _searchIndex('${prefix}_curators', query, limit, offset, filters)),
      _safeSearch(() =>
          _searchIndex('${prefix}_series', query, limit, offset, filters)),
    ];

    final results = await Future.wait(searchFutures);

    // Artworks
    final artworksIndex = results[0] as MeiliSearchIndexResult?;
    final artworksRaw = (artworksIndex?.hits ?? const <dynamic>[])
        .map((hit) => (hit as Map).cast<String, dynamic>())
        .toList();
    final artworks = artworksRaw
        .map((map) =>
            Artwork.fromJson(Map<String, dynamic>.from(map['artwork'] as Map)))
        .toList();
    final artworksRankingScore = artworksRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    // Exhibitions
    final exhibitionsIndex = results[1] as MeiliSearchIndexResult?;
    final exhibitionsRaw = (exhibitionsIndex?.hits ?? const <dynamic>[])
        .map((hit) => (hit as Map).cast<String, dynamic>())
        .toList();
    final exhibitions = exhibitionsRaw
        .map((map) => Exhibition.fromJson(
            Map<String, dynamic>.from(map['exhibition'] as Map)))
        .toList();
    final exhibitionsRankingScore = exhibitionsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    // Artists
    final artistsIndex = results[2] as MeiliSearchIndexResult?;
    final artistsRaw = (artistsIndex?.hits ?? const <dynamic>[])
        .map((hit) => (hit as Map).cast<String, dynamic>())
        .toList();
    final artists = artistsRaw
        .map((map) => AlumniAccount.fromJson(
            Map<String, dynamic>.from(map['artist'] as Map)))
        .toList();
    final artistsRankingScore = artistsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    // Curators
    final curatorsIndex = results[3] as MeiliSearchIndexResult?;
    final curatorsRaw = (curatorsIndex?.hits ?? const <dynamic>[])
        .map((hit) => (hit as Map).cast<String, dynamic>())
        .toList();
    final curators = curatorsRaw
        .map((map) => AlumniAccount.fromJson(
            Map<String, dynamic>.from(map['curator'] as Map)))
        .toList();
    final curatorsRankingScore = curatorsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    // Series
    final seriesIndex = results[4] as MeiliSearchIndexResult?;
    final seriesRaw = (seriesIndex?.hits ?? const <dynamic>[])
        .map((hit) => (hit as Map).cast<String, dynamic>())
        .toList();
    final series = seriesRaw
        .map((map) =>
            FFSeries.fromJson(Map<String, dynamic>.from(map['series'] as Map)))
        .toList();
    final seriesRankingScore = seriesRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    return MeiliSearchResult(
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
      processingTimeMs: 0, // Individual searches don't return processing time
    );
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

  /// Search artworks only
  Future<List<Artwork>> searchArtworks({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final result =
        await _searchIndex('${prefix}_artworks', query, limit, offset, filters);
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
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final result = await _searchIndex(
        '${prefix}_exhibitions', query, limit, offset, filters);
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
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final result =
        await _searchIndex('${prefix}_artists', query, limit, offset, filters);
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
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final result =
        await _searchIndex('${prefix}_curators', query, limit, offset, filters);
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
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final result =
        await _searchIndex('${prefix}_series', query, limit, offset, filters);
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

  /// Internal method to search a specific index
  Future<MeiliSearchIndexResult> _searchIndex(
    String indexName,
    String query,
    int limit,
    int offset,
    List<String>? filters,
  ) async {
    final requestBody = {
      'q': query,
      'limit': limit,
      'offset': offset,
      'showRankingScore': true,
      if (filters != null && filters.isNotEmpty) 'filter': filters,
    };

    final response = await _dio.post<Map<String, dynamic>>(
      '/indexes/$indexName/search',
      data: requestBody,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return MeiliSearchIndexResult.fromJson(data);
    } else {
      throw Exception('MeiliSearch API error: ${response.statusCode}');
    }
  }
}

/// Multi-search query for custom SDK
class CustomIndexSearchQuery {
  final String indexUid;
  final String query;
  final int limit;
  final int offset;
  final List<String>? filters;

  CustomIndexSearchQuery({
    required this.indexUid,
    required this.query,
    this.limit = 20,
    this.offset = 0,
    this.filters,
  });

  Map<String, dynamic> toMap() => {
        'indexUid': indexUid,
        'q': query,
        'limit': limit,
        'offset': offset,
        // Always request ranking scores as required
        'showRankingScore': true,
        if (filters != null && filters!.isNotEmpty) 'filter': filters,
      };
}

/// Result from a single MeiliSearch index
class MeiliSearchIndexResult {
  final List<dynamic> hits;
  final int totalHits;
  final int processingTimeMs;
  final String? query;

  MeiliSearchIndexResult({
    required this.hits,
    required this.totalHits,
    required this.processingTimeMs,
    this.query,
  });

  factory MeiliSearchIndexResult.fromJson(Map<String, dynamic> json) =>
      MeiliSearchIndexResult(
        hits: json['hits'] as List<dynamic>? ?? [],
        totalHits: (json['totalHits'] as int?) ??
            (json['estimatedTotalHits'] as int?) ??
            0,
        processingTimeMs: json['processingTimeMs'] as int? ?? 0,
        query: json['query'] as String?,
      );
}

// Removed custom multi-search result in favor of official MultiSearchResult
