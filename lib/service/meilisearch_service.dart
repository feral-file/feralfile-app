//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

/// Service for searching across multiple MeiliSearch indexes
class MeiliSearchService {
  MeiliSearchService._internal({this.prefix = 'ffprod'});

  /// Create a new instance with the specified prefix
  factory MeiliSearchService({String prefix = 'ffprod'}) =>
      MeiliSearchService._internal(prefix: prefix);

  late final Dio _dio;
  final String prefix;

  /// Initialize the service with MeiliSearch configuration
  void initialize() {
    _dio = DioManager().base(BaseOptions(
      baseUrl: Environment.meiliSearchUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer ${Environment.meiliSearchKey}',
        'Content-Type': 'application/json',
      },
    ));
  }

  /// Search across all indexes (artworks, exhibitions, artists, curators, series)
  Future<MeiliSearchResult> searchAll({
    required String query,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    // Execute all searches in parallel, but handle each one independently
    final searchFutures = [
      _safeSearch(() => searchArtworks(
          query: query, limit: limit, offset: offset, filters: filters)),
      _safeSearch(() => searchExhibitions(
          query: query, limit: limit, offset: offset, filters: filters)),
      _safeSearch(() => searchArtists(
          query: query, limit: limit, offset: offset, filters: filters)),
      _safeSearch(() => searchCurators(
          query: query, limit: limit, offset: offset, filters: filters)),
      _safeSearch(() => searchSeries(
          query: query, limit: limit, offset: offset, filters: filters)),
    ];

    final results = await Future.wait(searchFutures);

    // Extract results and handle nulls (failed searches)
    final artworks = results[0] as List<Artwork>? ?? <Artwork>[];
    final exhibitions = results[1] as List<Exhibition>? ?? <Exhibition>[];
    final artists = results[2] as List<AlumniAccount>? ?? <AlumniAccount>[];
    final curators = results[3] as List<AlumniAccount>? ?? <AlumniAccount>[];
    final series = results[4] as List<FFSeries>? ?? <FFSeries>[];

    return MeiliSearchResult(
      artworks: artworks,
      exhibitions: exhibitions,
      artists: artists,
      curators: curators,
      series: series,
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
      if (filters != null && filters.isNotEmpty) 'filter': filters,
    };

    final response = await _dio.post<Map<String, dynamic>>(
      '/indexes/$indexName/search',
      data: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return MeiliSearchIndexResult.fromJson(data);
    } else {
      throw Exception('MeiliSearch API error: ${response.statusCode}');
    }
  }
}

/// Result containing search results from all indexes
class MeiliSearchResult {
  final List<Artwork> artworks;
  final List<Exhibition> exhibitions;
  final List<AlumniAccount> artists;
  final List<AlumniAccount> curators;
  final List<FFSeries> series;
  final int totalHits;
  final int processingTimeMs;

  MeiliSearchResult({
    required this.artworks,
    required this.exhibitions,
    required this.artists,
    required this.curators,
    required this.series,
    required this.totalHits,
    required this.processingTimeMs,
  });

  factory MeiliSearchResult.empty() => MeiliSearchResult(
        artworks: [],
        exhibitions: [],
        artists: [],
        curators: [],
        series: [],
        totalHits: 0,
        processingTimeMs: 0,
      );

  /// Get all results combined as a single list
  List<dynamic> get allResults => [
        ...artworks,
        ...exhibitions,
        ...artists,
        ...curators,
        ...series,
      ];

  /// Check if any results exist
  bool get hasResults => allResults.isNotEmpty;

  /// Get total count of all results
  int get totalCount => allResults.length;
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
        totalHits: json['totalHits'] as int? ?? 0,
        processingTimeMs: json['processingTimeMs'] as int? ?? 0,
        query: json['query'] as String?,
      );
}
