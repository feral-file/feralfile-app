//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/util/dio_interceptors.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/timer_metric.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:meilisearch/meilisearch.dart';

/// Service for searching across multiple MeiliSearch indexes using the official MeiliSearch SDK
class MeiliSearchService {
  MeiliSearchService._internal({this.prefix = 'rag-dev'});

  /// Create a new instance with the specified prefix
  factory MeiliSearchService({String prefix = 'rag-dev'}) =>
      MeiliSearchService._internal(prefix: prefix);

  late final MeiliSearchClient _client;
  final String prefix;

  // late CustomMeiliSDK _customClient;

  /// Initialize the service with MeiliSearch configuration
  void initialize() {
    // _customClient = CustomMeiliSDK(prefix: prefix)..initialize();
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

  /// Search across all indexes (channels, playlists, playlist_items)
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
        indexUid: '${prefix}_channels',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
      IndexSearchQuery(
        indexUid: '${prefix}_playlists',
        query: text,
        limit: limit,
        offset: offset,
        showRankingScore: true,
      ),
      IndexSearchQuery(
        indexUid: '${prefix}_playlist_items',
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
    final channelsRaw = multiResult.results[0].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final channels = channelsRaw
        .map((map) =>
            Channel.fromJson(Map<String, dynamic>.from(map['channel'] as Map)))
        .toList();
    final channelsRankingScore = channelsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final playlistsRaw = multiResult.results[1].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final playlists = playlistsRaw
        .map((map) =>
            DP1Call.fromJson(Map<String, dynamic>.from(map['playlist'] as Map)))
        .toList();
    final playlistsRankingScore = playlistsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final itemsRaw = multiResult.results[2].hits
        .map((hit) => Map<String, dynamic>.from(hit as Map))
        .toList();
    final items = itemsRaw
        .map((map) => DP1Item.fromJson(
            Map<String, dynamic>.from(map['playlistItem'] as Map)))
        .toList();
    final itemsRankingScore = itemsRaw
        .map((m) => (m['_rankingScore'] as num?)?.toDouble() ?? 0.0)
        .toList();

    final result = MeiliSearchResult(
      channels: channels,
      playlists: playlists,
      items: items,
      channelsRankingScore: channelsRankingScore,
      playlistsRankingScore: playlistsRankingScore,
      itemsRankingScore: itemsRankingScore,
      totalHits: channels.length + playlists.length + items.length,
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

  // Removed: _safeSearch helper (no longer used)

  Future<Searcheable<Map<String, dynamic>>> _search(
      String text, String suffix, SearchQuery query) async {
    final indexName = '${prefix}_$suffix';
    final idx = _client.index(indexName);
    final res = await timerMetric(
        'Meili Search $indexName', () async => idx.search(text, query));
    return res;
  }

  /// Search channels only
  Future<List<Channel>> searchChannels({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'channels';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final json = Map<String, dynamic>.from(hit as Map);
        return Channel.fromJson(json);
      } catch (e) {
        log.warning('Failed to parse channel: $e');
        rethrow;
      }
    }).toList();
  }

  /// Search playlists only
  Future<List<DP1Call>> searchPlaylists({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'playlists';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final json = Map<String, dynamic>.from(hit as Map);
        return DP1Call.fromJson(json);
      } catch (e) {
        log.warning('Failed to parse playlist: $e');
        rethrow;
      }
    }).toList();
  }

  /// Search playlist items only
  Future<List<DP1Item>> searchPlaylistItems({
    required String text,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    const suffix = 'playlist_items';
    final searchQuery = SearchQuery(
      offset: offset,
      limit: limit,
    );

    final result = await _search(text, suffix, searchQuery);

    return result.hits.map((hit) {
      try {
        final json = Map<String, dynamic>.from(hit as Map);
        return DP1Item.fromJson(json);
      } catch (e) {
        log.warning('Failed to parse playlist item: $e');
        rethrow;
      }
    }).toList();
  }

  // Old search methods removed in favor of channels/playlists/playlist_items
}

/// Result class for MeiliSearch operations
// MeiliSearchResult moved to meilisearch_models.dart
