//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/model/token.dart';
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

/// Enum for MeiliSearch index types
enum MeiliSearchIndexType {
  channels,
  playlists,
  playlistItems,
  nftTokens,
}

/// Service for searching across multiple MeiliSearch indexes using the official MeiliSearch SDK
class MeiliSearchService {
  MeiliSearchService._internal({this.prefix = 'feed_prod'});

  /// Create a new instance with the specified prefix
  factory MeiliSearchService({String prefix = 'feed_prod'}) =>
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

  /// Search across specified indexes (channels, playlists, playlist_items) for multiple queries
  ///
  /// [texts] - List of search queries
  /// [indexTypes] - List of index types to search (default: all indexes)
  /// [offset] - Offset for pagination (default: 0)
  /// [limit] - Number of results to return (default: 10)
  /// [filters] - Optional filters
  Future<MeiliSearchResult> searchAll({
    required List<String> texts,
    List<MeiliSearchIndexType>? indexTypes,
    int offset = 0,
    int limit = 10,
    List<String>? filters,
  }) async {
    final start = DateTime.now();

    // Normalize queries (trim and remove empties). If empty, use single empty query to fetch defaults
    final normalizedTexts =
        texts.map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (normalizedTexts.isEmpty) {
      normalizedTexts.add('');
    }

    // Fetch more results from each index to ensure we get top N by ranking

    // Determine which indexes to search (default: all)
    final indexesToSearch = indexTypes ??
        [
          MeiliSearchIndexType.channels,
          MeiliSearchIndexType.playlists,
          MeiliSearchIndexType.playlistItems,
          MeiliSearchIndexType.nftTokens,
        ];

    // Build multi index query for all texts and specified indexes
    // Use offset=0 and limit=fetchLimit to get enough results for proper ranking
    final queries = <IndexSearchQuery>[];
    for (final text in normalizedTexts) {
      for (final indexType in indexesToSearch) {
        String indexUid;
        List<String>? attributesToRetrieve;
        switch (indexType) {
          case MeiliSearchIndexType.channels:
            indexUid = '${prefix}_channels';
            attributesToRetrieve = ['channel'];
            break;
          case MeiliSearchIndexType.playlists:
            indexUid = '${prefix}_playlists';
            attributesToRetrieve = ['playlist'];
            break;
          case MeiliSearchIndexType.playlistItems:
            indexUid = '${prefix}_playlist_items';
            attributesToRetrieve = ['playlistItem'];
            break;
          case MeiliSearchIndexType.nftTokens:
            indexUid = '${prefix}_nft_tokens';
            attributesToRetrieve = null; // Retrieve all attributes
            break;
        }

        queries.add(
          IndexSearchQuery(
            indexUid: indexUid,
            query: text,
            limit: limit,
            offset: 0,
            showRankingScore: true,
            attributesToRetrieve: attributesToRetrieve,
          ),
        );
      }
    }

    final multiResult = await timerMetric(
        'Meili Multi Search for ${normalizedTexts.join(', ')}',
        () async =>
            await _client.multiSearch(MultiSearchQuery(queries: queries)));

    // Group by indexUid, merge hits per index, and collect estimatedTotalHits
    final indexUidToHits = <String, List<Map<String, dynamic>>>{};
    final indexUidToEstimatedTotal = <String, int>{};
    for (final r in multiResult.results) {
      final uid = r.indexUid;
      final list =
          r.hits.map((hit) => Map<String, dynamic>.from(hit as Map)).toList();
      indexUidToHits
          .putIfAbsent(uid, () => <Map<String, dynamic>>[])
          .addAll(list);
      // Get estimatedTotalHits from response
      // Try to access estimatedTotalHits - it might be a property or need to be accessed differently
      final estimatedTotal = (r as dynamic).estimatedTotalHits as int? ?? 0;
      indexUidToEstimatedTotal[uid] = estimatedTotal;
    }

    final channelsRaw = indexUidToHits['${prefix}_channels'] ?? const [];
    final playlistsRaw = indexUidToHits['${prefix}_playlists'] ?? const [];
    final itemsRaw = indexUidToHits['${prefix}_playlist_items'] ?? const [];
    final nftTokensRaw = indexUidToHits['${prefix}_nft_tokens'] ?? const [];

    // Parse with scores and create unified list for sorting
    final allChannelPairs = channelsRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      final data =
          Channel.fromJson(Map<String, dynamic>.from(map['channel'] as Map));
      return Pair<Channel, double>(data, score);
    }).toList();
    final allPlaylistPairs = playlistsRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      final data =
          DP1Call.fromJson(Map<String, dynamic>.from(map['playlist'] as Map));
      return Pair<DP1Call, double>(data, score);
    }).toList();
    final allItemPairs = itemsRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      final data = DP1Item.fromJson(
          Map<String, dynamic>.from(map['playlistItem'] as Map));
      return Pair<DP1Item, double>(data, score);
    }).toList();
    final allNftTokenPairs = nftTokensRaw.map((map) {
      final score = (map['_rankingScore'] as num?)?.toDouble() ?? 0.0;
      // Remove _rankingScore from the map before parsing
      final hitData = Map<String, dynamic>.from(map);
      hitData.remove('_rankingScore');
      final data = AssetToken.fromMeilisearchResult(hitData);
      return Pair<AssetToken, double>(data, score);
    }).toList();

    // Get estimatedTotalHits for each index
    final channelsEstimatedTotal =
        indexUidToEstimatedTotal['${prefix}_channels'] ?? 0;
    final playlistsEstimatedTotal =
        indexUidToEstimatedTotal['${prefix}_playlists'] ?? 0;
    final itemsEstimatedTotal =
        indexUidToEstimatedTotal['${prefix}_playlist_items'] ?? 0;
    final nftTokensEstimatedTotal =
        indexUidToEstimatedTotal['${prefix}_nft_tokens'] ?? 0;

    // Separate back into channels, playlists, items, nftTokens with scores
    final channels = allChannelPairs.map((pair) => pair.first).toList();
    final playlists = allPlaylistPairs.map((pair) => pair.first).toList();
    final items = allItemPairs.map((pair) => pair.first).toList();
    final nftTokens = allNftTokenPairs.map((pair) => pair.first).toList();
    final channelsRankingScore =
        allChannelPairs.map((pair) => pair.second).toList();
    final playlistsRankingScore =
        allPlaylistPairs.map((pair) => pair.second).toList();
    final itemsRankingScore = allItemPairs.map((pair) => pair.second).toList();
    final nftTokensRankingScore =
        allNftTokenPairs.map((pair) => pair.second).toList();

    // Calculate maxRankingScore for each index
    double _maxOrZero(List<double> values) =>
        values.isEmpty ? 0.0 : values.reduce(math.max);

    final channelsMaxScore = _maxOrZero(channelsRankingScore);
    final playlistsMaxScore = _maxOrZero(playlistsRankingScore);
    final itemsMaxScore = _maxOrZero(itemsRankingScore);
    final nftTokensMaxScore = _maxOrZero(nftTokensRankingScore);

    // Create individual result objects for each index
    final channelsResult = MeiliSearchChannelResult(
      items: channels,
      maxRankingScore: channelsMaxScore,
      totalHits: channelsEstimatedTotal,
      offset: offset,
    );

    final playlistsResult = MeiliSearchPlaylistResult(
      items: playlists,
      maxRankingScore: playlistsMaxScore,
      totalHits: playlistsEstimatedTotal,
      offset: offset,
    );

    final worksResult = MeiliSearchWorksResult(
      items: items,
      maxRankingScore: itemsMaxScore,
      totalHits: itemsEstimatedTotal,
      offset: offset,
    );

    final nftTokensResult = MeiliSearchNftTokensResult(
      items: nftTokens,
      maxRankingScore: nftTokensMaxScore,
      totalHits: nftTokensEstimatedTotal,
      offset: offset,
    );

    final result = MeiliSearchResult(
      channels: channelsResult,
      playlists: playlistsResult,
      works: worksResult,
      nftTokens: nftTokensResult,
    );

    final processingTimeMs = multiResult.results
        .fold(0, (sum, r) => sum + (r.processingTimeMs ?? 0));
    log.info(
        'MeiliSearchService.searchAll processing time: $processingTimeMs ms');
    log.info(
        'MeiliSearchService.searchAll completed in ${DateTime.now().difference(start).inMilliseconds} ms with total hits: ${result.totalHits}');
    return result;
  }

  Future<Searcheable<Map<String, dynamic>>> _search(
      String text, String suffix, SearchQuery query) async {
    final indexName = '${prefix}_$suffix';
    final idx = _client.index(indexName);
    final res = await timerMetric(
        'Meili Search $indexName', () async => idx.search(text, query));
    return res;
  }
}

/// Result class for MeiliSearch operations
// MeiliSearchResult moved to meilisearch_models.dart
