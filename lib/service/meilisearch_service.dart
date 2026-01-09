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
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
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

class IndexSearchQueryBuilder {
  IndexSearchQueryBuilder({
    required this.prefix,
    required this.indexType,
    required this.query,
  });

  final String prefix;
  final MeiliSearchIndexType indexType;
  final String query;

  int _limit = 10;
  int _offset = 0;
  List<String>? _filters;
  List<String>? _sort;
  List<String>? _attributesToRetrieve;

  IndexSearchQueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  IndexSearchQueryBuilder offset(int value) {
    _offset = value;
    return this;
  }

  IndexSearchQueryBuilder filters(List<String>? filters) {
    _filters = filters;
    return this;
  }

  IndexSearchQueryBuilder sort(List<String>? sort) {
    _sort = sort;
    return this;
  }

  IndexSearchQueryBuilder attributesToRetrieve(List<String>? attrs) {
    _attributesToRetrieve = attrs;
    return this;
  }

  IndexSearchQuery build() {
    final indexUid = _buildIndexUid();
    final attrs = _buildAttributesToRetrieve();

    return IndexSearchQuery(
      indexUid: indexUid,
      query: query,
      limit: _limit,
      offset: _offset,
      showRankingScore: true,
      attributesToRetrieve: attrs,
      // These fields depend on the MeiliSearch Dart client signature.
      // We pass through filters and sort if they are supported.
      filter: _filters?.map((filter) => '($filter)').join(' AND '),
      sort: _sort,
    );
  }

  String _buildIndexUid() {
    switch (indexType) {
      case MeiliSearchIndexType.channels:
        return '${prefix}_channels';
      case MeiliSearchIndexType.playlists:
        return '${prefix}_playlists';
      case MeiliSearchIndexType.playlistItems:
        return '${prefix}_playlist_items';
      case MeiliSearchIndexType.nftTokens:
        return '${prefix}_nft_tokens';
    }
  }

  List<String>? _buildAttributesToRetrieve() {
    if (_attributesToRetrieve != null) {
      return _attributesToRetrieve;
    }

    switch (indexType) {
      case MeiliSearchIndexType.channels:
        return ['channel'];
      case MeiliSearchIndexType.playlists:
        return ['playlist'];
      case MeiliSearchIndexType.playlistItems:
        return ['playlistItem'];
      case MeiliSearchIndexType.nftTokens:
        // Retrieve full document for nft_tokens.
        return null;
    }
  }
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

  Future<MeiliSearchResult> searchAll({
    required List<IndexSearchQuery> queries,
  }) async {
    final start = DateTime.now();
    log.info(
      'MeiliSearchService.searchAll queries: ${queries.map(
        (query) {
          final map = Map<String, Object?>.from(query.buildMap());
          map.removeWhere((key, value) => value == null);
          return map;
        },
      ).toList()}',
    );

    final multiResult = await timerMetric(
        'Meili Multi Search for ${queries.length} queries',
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
    // For now, we use a shared offset of 0 for all indexes in the aggregated result.
    const aggregatedOffset = 0;

    final channelsResult = MeiliSearchChannelResult(
      items: channels,
      maxRankingScore: channelsMaxScore,
      totalHits: channelsEstimatedTotal,
      offset: aggregatedOffset,
    );

    final playlistsResult = MeiliSearchPlaylistResult(
      items: playlists,
      maxRankingScore: playlistsMaxScore,
      totalHits: playlistsEstimatedTotal,
      offset: aggregatedOffset,
    );

    final worksResult = MeiliSearchWorksResult(
      items: items,
      maxRankingScore: itemsMaxScore,
      totalHits: itemsEstimatedTotal,
      offset: aggregatedOffset,
    );

    final nftTokensResult = MeiliSearchNftTokensResult(
      items: nftTokens,
      maxRankingScore: nftTokensMaxScore,
      totalHits: nftTokensEstimatedTotal,
      offset: aggregatedOffset,
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

  /// Get facet values for a specific index type.
  ///
  /// Returns a map of SearchFilterBy to list of available facet values.
  Future<Map<SearchFilterBy, List<String>>> getFacetValuesForIndex(
    MeiliSearchIndexType indexType,
  ) async {
    final supportedFilters = indexType.supportedFilters;
    if (supportedFilters.isEmpty) {
      return {};
    }

    final indexUid = _buildIndexUid(indexType);
    final index = _client.index(indexUid);

    // Get field names for facets
    final facetFields =
        supportedFilters.map((filter) => filter.meiliFieldName).toList();

    // Perform a search with facets to get facet distribution
    // Use empty query to get all facet values
    final query = SearchQuery(
      facets: facetFields,
      limit: 0, // We only need facets, not hits
    );

    final result = await index.search('', query);
    final facetDistribution = result.facetDistribution as Map<String, dynamic>?;

    final facetValues = <SearchFilterBy, List<String>>{};

    if (facetDistribution != null) {
      for (final filter in supportedFilters) {
        final fieldName = filter.meiliFieldName;
        final distribution =
            facetDistribution[fieldName] as Map<String, dynamic>?;
        if (distribution != null) {
          final values = distribution.keys.toList()..sort();
          facetValues[filter] = values;
        } else {
          facetValues[filter] = [];
        }
      }
    } else {
      // If no facet distribution, return empty lists
      for (final filter in supportedFilters) {
        facetValues[filter] = [];
      }
    }

    return facetValues;
  }

  String _buildIndexUid(MeiliSearchIndexType indexType) {
    switch (indexType) {
      case MeiliSearchIndexType.channels:
        return '${prefix}_channels';
      case MeiliSearchIndexType.playlists:
        return '${prefix}_playlists';
      case MeiliSearchIndexType.playlistItems:
        return '${prefix}_playlist_items';
      case MeiliSearchIndexType.nftTokens:
        return '${prefix}_nft_tokens';
    }
  }
}

/// Result class for MeiliSearch operations
// MeiliSearchResult moved to meilisearch_models.dart
