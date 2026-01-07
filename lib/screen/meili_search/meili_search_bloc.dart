//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:math' as math;

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:autonomy_flutter/util/latest_async.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SearchFilterType {
  channels,
  playlists,
  items,
  nftTokens,
}

abstract class MeiliSearchEvent {}

class MeiliSearchQuerySubmitted extends MeiliSearchEvent {
  final String query;

  MeiliSearchQuerySubmitted(this.query);
}

class MeiliSearchFilterTypeChanged extends MeiliSearchEvent {
  final SearchFilterType filterType;

  MeiliSearchFilterTypeChanged(this.filterType);
}

class MeiliSearchCleared extends MeiliSearchEvent {}

class MeiliSearchLoadMore extends MeiliSearchEvent {
  final Set<MeiliSearchIndexType> indexTypes;

  MeiliSearchLoadMore(this.indexTypes);
}

class MeiliSearchState {
  final String query;
  final SearchFilterType filterType;
  final MeiliSearchResult? result;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;

  MeiliSearchState({
    this.query = '',
    this.filterType = SearchFilterType.channels,
    this.result,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
  });

  MeiliSearchState copyWith({
    String? query,
    SearchFilterType? filterType,
    MeiliSearchResult? result,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
  }) {
    return MeiliSearchState(
      query: query ?? this.query,
      filterType: filterType ?? this.filterType,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Convenience getters for backward compatibility
  List<Channel> get channels => result?.channels.items ?? const [];
  List<DP1Call> get playlists => result?.playlists.items ?? const [];
  List<DP1Item> get items => result?.works.items ?? const [];
  List<AssetToken> get nftTokens => result?.nftTokens.items ?? const [];
  double get channelsTopScore => result?.channels.maxRankingScore ?? 0.0;
  double get playlistsTopScore => result?.playlists.maxRankingScore ?? 0.0;
  double get itemsTopScore => result?.works.maxRankingScore ?? 0.0;
  double get nftTokensTopScore => result?.nftTokens.maxRankingScore ?? 0.0;

  bool get hasResults =>
      channels.isNotEmpty ||
      playlists.isNotEmpty ||
      items.isNotEmpty ||
      nftTokens.isNotEmpty;

  bool get isEmpty => !hasResults && !isLoading && query.isNotEmpty;
}

class MeiliSearchBloc extends AuBloc<MeiliSearchEvent, MeiliSearchState> {
  final MeiliSearchService _meiliSearchService;
  final int pageSize;
  final LatestAsync<MeiliSearchResult> _latestSearch =
      LatestAsync<MeiliSearchResult>();

  MeiliSearchBloc(
    this._meiliSearchService, {
    this.pageSize = 10,
  }) : super(MeiliSearchState()) {
    on<MeiliSearchQuerySubmitted>(_onQuerySubmitted);
    on<MeiliSearchFilterTypeChanged>(_onFilterTypeChanged);
    on<MeiliSearchCleared>(_onCleared);
    on<MeiliSearchLoadMore>(_onLoadMore);
  }

  @override
  void add(MeiliSearchEvent event) {
    log.info('MeiliSearchBloc event: $event');
    super.add(event);
  }

  Future<void> _onQuerySubmitted(
    MeiliSearchQuerySubmitted event,
    Emitter<MeiliSearchState> emit,
  ) async {
    final start = DateTime.now();
    final query = event.query.trim();

    if (query.isEmpty) {
      emit(state.copyWith(
        query: '',
        isLoading: false,
        hasError: false,
        errorMessage: null,
      ));
      return;
    }

    emit(state.copyWith(
      query: query,
      isLoading: true,
      hasError: false,
      errorMessage: null,
    ));

    try {
      // Always call searchAll() to search across all indexes
      // Start from offset 0
      const offset = 0;
      await _latestSearch.run(
        () async => _meiliSearchService.searchAll(
          texts: [query],
          offset: offset,
          limit: pageSize,
        ),
        onData: (result) {
          final channels = result.channels.items;
          final playlists = result.playlists.items;
          final items = result.works.items;
          final nftTokens = result.nftTokens.items;

          final channelsTop = result.channels.maxRankingScore;
          final playlistsTop = result.playlists.maxRankingScore;
          final itemsTop = result.works.maxRankingScore;
          final nftTokensTop = result.nftTokens.maxRankingScore;

          // Pick filter type with highest topScore among non-empty sections
          var nextFilterType = state.filterType;
          var bestScore = -1.0;

          void considerType(
            SearchFilterType type,
            List<dynamic> list,
            double score,
          ) {
            if (list.isNotEmpty && score >= 0 && score >= bestScore) {
              bestScore = score;
              nextFilterType = type;
            }
          }

          considerType(SearchFilterType.channels, channels, channelsTop);
          considerType(SearchFilterType.playlists, playlists, playlistsTop);
          considerType(SearchFilterType.items, items, itemsTop);
          considerType(SearchFilterType.nftTokens, nftTokens, nftTokensTop);

          emit(
            state.copyWith(
              result: result,
              filterType: nextFilterType,
              isLoading: false,
            ),
          );

          final duration = DateTime.now().difference(start);
          log.info(
              '_onQuerySubmitted MeiliSearch query "$query" took ${duration.inMilliseconds} ms, totalHits: ${result.totalHits}');
        },
        onError: (e, st) {
          log.severe('MeiliSearch error: $e');
          emit(state.copyWith(
            isLoading: false,
            hasError: true,
            errorMessage: e.toString(),
          ));
        },
      );
    } catch (e) {
      log.severe('MeiliSearch error: $e');
      emit(state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      ));
    }

    log.info('_onQuerySubmitted MeiliSearch finished');
  }

  Future<void> _onFilterTypeChanged(
    MeiliSearchFilterTypeChanged event,
    Emitter<MeiliSearchState> emit,
  ) async {
    // Only update filterType, no need to re-search since we already have all results
    emit(state.copyWith(
      filterType: event.filterType,
    ));
  }

  Future<void> _onCleared(
    MeiliSearchCleared event,
    Emitter<MeiliSearchState> emit,
  ) async {
    emit(MeiliSearchState());
  }

  Future<void> _onLoadMore(
    MeiliSearchLoadMore event,
    Emitter<MeiliSearchState> emit,
  ) async {
    if (state.isLoading || state.result == null) {
      return;
    }

    final start = DateTime.now();
    final existingResult = state.result!;
    emit(state.copyWith(isLoading: true));

    try {
      // Load more for each requested index type
      MeiliSearchChannelResult? newChannelsResult;
      MeiliSearchPlaylistResult? newPlaylistsResult;
      MeiliSearchWorksResult? newWorksResult;
      MeiliSearchNftTokensResult? newNftTokensResult;

      // Load more for requested indexes
      if (event.indexTypes.isEmpty) {
        emit(state.copyWith(isLoading: false));
        return;
      }

      // Calculate next offset for each requested index
      final indexToOffset = <MeiliSearchIndexType, int>{};
      final indexToHasMore = <MeiliSearchIndexType, bool>{};

      for (final indexType in event.indexTypes) {
        int currentOffset;
        int currentItemsCount;
        int totalHits;
        switch (indexType) {
          case MeiliSearchIndexType.channels:
            currentOffset = existingResult.channels.offset;
            currentItemsCount = existingResult.channels.items.length;
            totalHits = existingResult.channels.totalHits;
          case MeiliSearchIndexType.playlists:
            currentOffset = existingResult.playlists.offset;
            currentItemsCount = existingResult.playlists.items.length;
            totalHits = existingResult.playlists.totalHits;
          case MeiliSearchIndexType.playlistItems:
            currentOffset = existingResult.works.offset;
            currentItemsCount = existingResult.works.items.length;
            totalHits = existingResult.works.totalHits;
          case MeiliSearchIndexType.nftTokens:
            currentOffset = existingResult.nftTokens.offset;
            currentItemsCount = existingResult.nftTokens.items.length;
            totalHits = existingResult.nftTokens.totalHits;
        }

        final nextOffset = currentOffset + currentItemsCount;
        final hasMore = nextOffset < totalHits;
        indexToHasMore[indexType] = hasMore;
        if (hasMore) {
          indexToOffset[indexType] = nextOffset;
        }
      }

      // Load more for all requested indexes in one call
      if (indexToOffset.isNotEmpty) {
        // Use the minimum offset for all indexes (they should be similar)
        final minOffset = indexToOffset.values.reduce((a, b) => a < b ? a : b);
        final newResult = await _meiliSearchService.searchAll(
          texts: [state.query],
          indexTypes: event.indexTypes.toList(),
          offset: minOffset,
          limit: pageSize,
        );

        // Extract results for each index
        if (event.indexTypes.contains(MeiliSearchIndexType.channels) &&
            indexToHasMore[MeiliSearchIndexType.channels] == true) {
          newChannelsResult = newResult.channels;
        }
        if (event.indexTypes.contains(MeiliSearchIndexType.playlists) &&
            indexToHasMore[MeiliSearchIndexType.playlists] == true) {
          newPlaylistsResult = newResult.playlists;
        }
        if (event.indexTypes.contains(MeiliSearchIndexType.playlistItems) &&
            indexToHasMore[MeiliSearchIndexType.playlistItems] == true) {
          newWorksResult = newResult.works;
        }
        if (event.indexTypes.contains(MeiliSearchIndexType.nftTokens) &&
            indexToHasMore[MeiliSearchIndexType.nftTokens] == true) {
          newNftTokensResult = newResult.nftTokens;
        }
      }

      // Merge results
      final mergedChannels = newChannelsResult != null
          ? MeiliSearchChannelResult(
              items: [
                ...existingResult.channels.items,
                ...newChannelsResult.items,
              ],
              maxRankingScore: math.max(
                existingResult.channels.maxRankingScore,
                newChannelsResult.maxRankingScore,
              ),
              totalHits: newChannelsResult.totalHits,
              offset: newChannelsResult.offset,
            )
          : existingResult.channels;

      final mergedPlaylists = newPlaylistsResult != null
          ? MeiliSearchPlaylistResult(
              items: [
                ...existingResult.playlists.items,
                ...newPlaylistsResult.items,
              ],
              maxRankingScore: math.max(
                existingResult.playlists.maxRankingScore,
                newPlaylistsResult.maxRankingScore,
              ),
              totalHits: newPlaylistsResult.totalHits,
              offset: newPlaylistsResult.offset,
            )
          : existingResult.playlists;

      final mergedWorks = newWorksResult != null
          ? MeiliSearchWorksResult(
              items: [
                ...existingResult.works.items,
                ...newWorksResult.items,
              ],
              maxRankingScore: math.max(
                existingResult.works.maxRankingScore,
                newWorksResult.maxRankingScore,
              ),
              totalHits: newWorksResult.totalHits,
              offset: newWorksResult.offset,
            )
          : existingResult.works;

      final mergedNftTokens = newNftTokensResult != null
          ? MeiliSearchNftTokensResult(
              items: [
                ...existingResult.nftTokens.items,
                ...newNftTokensResult.items,
              ],
              maxRankingScore: math.max(
                existingResult.nftTokens.maxRankingScore,
                newNftTokensResult.maxRankingScore,
              ),
              totalHits: newNftTokensResult.totalHits,
              offset: newNftTokensResult.offset,
            )
          : existingResult.nftTokens;

      final mergedResult = MeiliSearchResult(
        channels: mergedChannels,
        playlists: mergedPlaylists,
        works: mergedWorks,
        nftTokens: mergedNftTokens,
      );

      emit(
        state.copyWith(
          result: mergedResult,
          isLoading: false,
        ),
      );

      final duration = DateTime.now().difference(start);
      log.info(
          '_onLoadMore MeiliSearch query "${state.query}" for ${event.indexTypes} took ${duration.inMilliseconds} ms');
    } catch (e) {
      log.severe('MeiliSearch load more error: $e');
      emit(state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      ));
    }

    log.info('_onLoadMore MeiliSearch finished');
  }
}
