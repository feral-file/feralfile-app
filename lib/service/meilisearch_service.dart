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

  /// Search across all indexes (channels, playlists, playlist_items) for multiple queries
  Future<MeiliSearchResult> searchAll({
    required List<String> texts,
    int limit = 20,
    int offset = 0,
    List<String>? filters,
  }) async {
    final start = DateTime.now();

    // Normalize queries (trim and remove empties). If empty, use single empty query to fetch defaults
    final normalizedTexts =
        texts.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (normalizedTexts.isEmpty) {
      normalizedTexts.add('');
    }

    // Build multi index query for all texts and all indexes
    final queries = <IndexSearchQuery>[];
    for (final text in normalizedTexts) {
      queries.addAll([
        IndexSearchQuery(
          indexUid: '${prefix}_channels',
          query: text,
          limit: limit,
          offset: offset,
          showRankingScore: true,
          attributesToRetrieve: ['channel'],
        ),
        IndexSearchQuery(
          indexUid: '${prefix}_playlists',
          query: text,
          limit: limit,
          offset: offset,
          showRankingScore: true,
          attributesToRetrieve: ['playlist'],
        ),
        IndexSearchQuery(
          indexUid: '${prefix}_playlist_items',
          query: text,
          limit: limit,
          offset: offset,
          showRankingScore: true,
          attributesToRetrieve: ['playlistItem'],
        ),
      ]);
    }

    final multiResult = await timerMetric(
        'Meili Multi Search for ${normalizedTexts.join(', ')}',
        () async =>
            await _client.multiSearch(MultiSearchQuery(queries: queries)));

    // Group by indexUid, merge hits per index, then parse with the old logic
    final indexUidToHits = <String, List<Map<String, dynamic>>>{};
    for (final r in multiResult.results) {
      final uid = r.indexUid;
      final list =
          r.hits.map((hit) => Map<String, dynamic>.from(hit as Map)).toList();
      indexUidToHits
          .putIfAbsent(uid, () => <Map<String, dynamic>>[])
          .addAll(list);
    }

    final channelsRaw = indexUidToHits['${prefix}_channels'] ?? const [];
    final playlistsRaw = indexUidToHits['${prefix}_playlists'] ?? const [];
    final itemsRaw = indexUidToHits['${prefix}_playlist_items'] ?? const [];

    // Parse with scores
    final channelPairs = channelsRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      final data =
          Channel.fromJson(Map<String, dynamic>.from(map['channel'] as Map));
      return (data: data, score: score);
    }).toList();
    final playlistPairs = playlistsRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      final data =
          DP1Call.fromJson(Map<String, dynamic>.from(map['playlist'] as Map));
      return (data: data, score: score);
    }).toList();
    final itemPairs = itemsRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      final data = DP1Item.fromJson(
          Map<String, dynamic>.from(map['playlistItem'] as Map));
      return (data: data, score: score);
    }).toList();

    // Sort by score desc first
    channelPairs.sort((a, b) => b.score.compareTo(a.score));
    playlistPairs.sort((a, b) => b.score.compareTo(a.score));
    itemPairs.sort((a, b) => b.score.compareTo(a.score));

    // Extract ordered lists first
    final channels = channelPairs.map((e) => e.data).toList();
    final playlists = playlistPairs.map((e) => e.data).toList();
    final items = itemPairs.map((e) => e.data).toList();

    final channelsRankingScore = channelPairs.map((e) => e.score).toList();
    final playlistsRankingScore = playlistPairs.map((e) => e.score).toList();
    final itemsRankingScore = itemPairs.map((e) => e.score).toList();

    // Remove duplicates after extracting data to keep highest ranking items
    final uniqueChannels = channels.removeDuplicates();
    final uniquePlaylists = playlists.removeDuplicates();
    final uniqueItems = items.removeDuplicates();

    final result = MeiliSearchResult(
      channels: uniqueChannels,
      playlists: uniquePlaylists,
      items: uniqueItems,
      channelsRankingScore: channelsRankingScore,
      playlistsRankingScore: playlistsRankingScore,
      itemsRankingScore: itemsRankingScore,
      totalHits:
          uniqueChannels.length + uniquePlaylists.length + uniqueItems.length,
      processingTimeMs: multiResult.results
          .fold(0, (sum, r) => sum + (r.processingTimeMs ?? 0)),
    );

    log.info(
        'MeiliSearchService.searchAll processing time: ${result.processingTimeMs} ms');
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
