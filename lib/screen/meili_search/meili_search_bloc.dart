//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:math' as math;

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/index_search_query_helper.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:autonomy_flutter/util/latest_async.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meilisearch/meilisearch.dart';

enum SearchFilterType {
  channels,
  playlists,
  items,
  nftTokens,
}

enum SearchSortOrder {
  relevance,
  aToZ,
  recent,
}

enum SearchFilterBy {
  // For nftTokens
  chain,
  standard,
  artist,
  // For channels
  curator,
  publisher,
  // For playlists
  dp1Version,
}

extension SearchFilterTypeExt on SearchFilterType {
  List<SearchSortOrder> get allowedSortOrders {
    switch (this) {
      case SearchFilterType.channels:
      case SearchFilterType.playlists:
        return [
          SearchSortOrder.relevance,
          SearchSortOrder.aToZ,
        ];
      case SearchFilterType.items:
        return [SearchSortOrder.relevance];
      case SearchFilterType.nftTokens:
        return [
          SearchSortOrder.relevance,
          SearchSortOrder.aToZ,
          SearchSortOrder.recent,
        ];
    }
  }

  SearchSortOrder get defaultSortOrder => SearchSortOrder.relevance;

  String get label {
    switch (this) {
      case SearchFilterType.channels:
        return 'Channels';
      case SearchFilterType.playlists:
        return 'Playlists';
      case SearchFilterType.items:
        return 'Works';
      case SearchFilterType.nftTokens:
        return 'Collections';
    }
  }

  List<SearchFilterBy> get supportedFilters {
    switch (this) {
      case SearchFilterType.nftTokens:
        return [
          SearchFilterBy.chain,
          SearchFilterBy.standard,
          SearchFilterBy.artist,
        ];
      case SearchFilterType.channels:
        return [
          SearchFilterBy.curator,
          SearchFilterBy.publisher,
        ];
      case SearchFilterType.playlists:
        return [SearchFilterBy.dp1Version];
      case SearchFilterType.items:
        return [];
    }
  }
}

extension SearchSortOrderExt on SearchSortOrder {
  String get label {
    switch (this) {
      case SearchSortOrder.relevance:
        return 'Relevance';
      case SearchSortOrder.aToZ:
        return 'A to Z';
      case SearchSortOrder.recent:
        return 'Recent';
    }
  }
}

extension SearchFilterByExt on SearchFilterBy {
  String get label {
    switch (this) {
      case SearchFilterBy.chain:
        return 'Chain';
      case SearchFilterBy.standard:
        return 'Standard';
      case SearchFilterBy.artist:
        return 'Artist';
      case SearchFilterBy.curator:
        return 'Curator';
      case SearchFilterBy.publisher:
        return 'Publisher';
      case SearchFilterBy.dp1Version:
        return 'DP-1 Version';
    }
  }

  String get meiliFieldName {
    switch (this) {
      case SearchFilterBy.chain:
        return 'chain';
      case SearchFilterBy.standard:
        return 'standard';
      case SearchFilterBy.artist:
        return 'artist_name';
      case SearchFilterBy.curator:
        return 'curator';
      case SearchFilterBy.publisher:
        return 'publisher';
      case SearchFilterBy.dp1Version:
        return 'dp_version';
    }
  }
}

extension MeiliSearchIndexTypeExt on MeiliSearchIndexType {
  List<SearchFilterBy> get supportedFilters {
    switch (this) {
      case MeiliSearchIndexType.nftTokens:
        return [
          SearchFilterBy.chain,
          SearchFilterBy.standard,
          SearchFilterBy.artist,
        ];
      case MeiliSearchIndexType.channels:
        return [
          SearchFilterBy.curator,
          SearchFilterBy.publisher,
        ];
      case MeiliSearchIndexType.playlists:
        return [SearchFilterBy.dp1Version];
      case MeiliSearchIndexType.playlistItems:
        return [];
    }
  }
}

class MeiliFilterSelection {
  MeiliFilterSelection({
    required this.filterBy,
    Set<String>? value,
  }) : value = value ?? {};

  final SearchFilterBy filterBy;
  final Set<String> value;

  MeiliFilterSelection copyWith({
    SearchFilterBy? filterBy,
    Set<String>? value,
  }) {
    return MeiliFilterSelection(
      filterBy: filterBy ?? this.filterBy,
      value: value ?? this.value,
    );
  }

  bool get isEmpty => value.isEmpty;

  MeiliFilterSelection toggleValue(String val) {
    final newSet = Set<String>.from(value);
    if (newSet.contains(val)) {
      newSet.remove(val);
    } else {
      newSet.add(val);
    }
    return MeiliFilterSelection(
      filterBy: filterBy,
      value: newSet,
    );
  }
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

class MeiliSearchSortChanged extends MeiliSearchEvent {
  MeiliSearchSortChanged(this.sortOrder);

  final SearchSortOrder sortOrder;
}

class MeiliSearchFilterToggled extends MeiliSearchEvent {
  MeiliSearchFilterToggled({
    required this.filterType,
    required this.selections,
  });

  final SearchFilterType filterType;
  final List<MeiliFilterSelection> selections;
}

class MeiliSearchState {
  final String query;
  final SearchFilterType filterType;
  final MeiliSearchResult? result;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final SearchSortOrder sortOrder;
  final Map<SearchFilterType, List<MeiliFilterSelection>> filtersByType;

  MeiliSearchState({
    this.query = '',
    this.filterType = SearchFilterType.channels,
    this.result,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.sortOrder = SearchSortOrder.relevance,
    Map<SearchFilterType, List<MeiliFilterSelection>>? filtersByType,
  }) : filtersByType = filtersByType ?? {};

  MeiliSearchState copyWith({
    String? query,
    SearchFilterType? filterType,
    MeiliSearchResult? result,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    SearchSortOrder? sortOrder,
    Map<SearchFilterType, List<MeiliFilterSelection>>? filtersByType,
  }) {
    final nextFilterType = filterType ?? this.filterType;
    final rawNextSortOrder = sortOrder ?? this.sortOrder;
    final normalizedSortOrder =
        nextFilterType.allowedSortOrders.contains(rawNextSortOrder)
            ? rawNextSortOrder
            : nextFilterType.defaultSortOrder;

    return MeiliSearchState(
      query: query ?? this.query,
      filterType: nextFilterType,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      sortOrder: normalizedSortOrder,
      filtersByType: filtersByType ?? this.filtersByType,
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
    on<MeiliSearchSortChanged>(_onSortChanged);
    on<MeiliSearchFilterToggled>(_onFilterToggled);
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
      await _latestSearch.run(
        () async {
          final indexTypes = <MeiliSearchIndexType>[
            MeiliSearchIndexType.channels,
            MeiliSearchIndexType.playlists,
            MeiliSearchIndexType.playlistItems,
            MeiliSearchIndexType.nftTokens,
          ];

          final queries = <IndexSearchQuery>[];
          for (final indexType in indexTypes) {
            final builder = IndexSearchQueryBuilder(
              prefix: _meiliSearchService.prefix,
              indexType: indexType,
              query: query,
            )
              ..limit(pageSize)
              ..offset(0);

            // Apply sort based on current filter type and sort order.
            final sort = _buildSortForIndexType(indexType, state.sortOrder);
            if (sort != null && sort.isNotEmpty) {
              builder.sort(sort);
            }

            // Apply filters for this index type
            final filterType = _mapIndexTypeToSearchFilterType(indexType);
            final selections = state.filtersByType[filterType];
            final filters = _buildFiltersForIndexType(indexType, selections);
            if (filters != null && filters.isNotEmpty) {
              builder.filters(filters);
            }

            // Add filter for nft tokens if the index type is nft tokens
            if (indexType == MeiliSearchIndexType.nftTokens) {
              final ownerAddress =
                  await injector<AddressService>().getAllAddresses();
              final addressFilter =
                  IndexSearchQueryHelper.buildNftTokensOwnerFilter(
                      ownerAddress);
              if (addressFilter != null) {
                final existingFilters = filters ?? <String>[];
                builder.filters([...existingFilters, addressFilter]);
              }
            }

            queries.add(builder.build());
          }

          return _meiliSearchService.searchAll(queries: queries);
        },
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
    // Only update filterType and normalize sortOrder for that type,
    // no need to re-search since we already have all results.
    emit(state.copyWith(
      filterType: event.filterType,
    ));
  }

  Future<void> _onSortChanged(
    MeiliSearchSortChanged event,
    Emitter<MeiliSearchState> emit,
  ) async {
    // Update sortOrder.
    final updatedState = state.copyWith(sortOrder: event.sortOrder);
    emit(updatedState);

    // Only re-sort current selected index type; keep other indexes as-is.
    final currentQuery = updatedState.query.trim();
    final existingResult = updatedState.result;

    if (currentQuery.isEmpty || existingResult == null) {
      // Nothing to re-sort; new query will pick up sortOrder.
      return;
    }

    try {
      final filterType = updatedState.filterType;

      MeiliSearchIndexType indexType;
      int limit;

      switch (filterType) {
        case SearchFilterType.channels:
          indexType = MeiliSearchIndexType.channels;
          limit = existingResult.channels.items.length;
        case SearchFilterType.playlists:
          indexType = MeiliSearchIndexType.playlists;
          limit = existingResult.playlists.items.length;
        case SearchFilterType.items:
          indexType = MeiliSearchIndexType.playlistItems;
          limit = existingResult.works.items.length;
        case SearchFilterType.nftTokens:
          indexType = MeiliSearchIndexType.nftTokens;
          limit = existingResult.nftTokens.items.length;
      }

      if (limit == 0) {
        // No items for this type to sort.
        return;
      }

      final builder = IndexSearchQueryBuilder(
        prefix: _meiliSearchService.prefix,
        indexType: indexType,
        query: currentQuery,
      )
        ..limit(limit)
        ..offset(0);

      final sort = _buildSortForIndexType(indexType, updatedState.sortOrder);
      if (sort != null && sort.isNotEmpty) {
        builder.sort(sort);
      }

      // Apply filters for this index type
      final filterTypeForFilters = _mapIndexTypeToSearchFilterType(indexType);
      final selections = updatedState.filtersByType[filterTypeForFilters];
      final filters = _buildFiltersForIndexType(indexType, selections);
      if (filters != null && filters.isNotEmpty) {
        builder.filters(filters);
      }

      // Apply nftTokens owner filter if needed.
      if (indexType == MeiliSearchIndexType.nftTokens) {
        final ownerAddress = await injector<AddressService>().getAllAddresses();
        final addressFilter =
            IndexSearchQueryHelper.buildNftTokensOwnerFilter(ownerAddress);
        if (addressFilter != null) {
          final existingFilters = filters ?? <String>[];
          builder.filters([...existingFilters, addressFilter]);
        }
      }

      final newResultForType =
          await _meiliSearchService.searchAll(queries: [builder.build()]);

      MeiliSearchResult merged;
      switch (filterType) {
        case SearchFilterType.channels:
          merged = MeiliSearchResult(
            channels: newResultForType.channels,
            playlists: existingResult.playlists,
            works: existingResult.works,
            nftTokens: existingResult.nftTokens,
          );
        case SearchFilterType.playlists:
          merged = MeiliSearchResult(
            channels: existingResult.channels,
            playlists: newResultForType.playlists,
            works: existingResult.works,
            nftTokens: existingResult.nftTokens,
          );
        case SearchFilterType.items:
          merged = MeiliSearchResult(
            channels: existingResult.channels,
            playlists: existingResult.playlists,
            works: newResultForType.works,
            nftTokens: existingResult.nftTokens,
          );
        case SearchFilterType.nftTokens:
          merged = MeiliSearchResult(
            channels: existingResult.channels,
            playlists: existingResult.playlists,
            works: existingResult.works,
            nftTokens: newResultForType.nftTokens,
          );
      }

      emit(
        updatedState.copyWith(
          result: merged,
        ),
      );
    } catch (e) {
      log.severe('MeiliSearch sort change error: $e');
      emit(
        updatedState.copyWith(
          hasError: true,
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
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
        final queries = <IndexSearchQuery>[];
        for (final indexType in event.indexTypes) {
          final hasMore = indexToHasMore[indexType] == true;
          final nextOffset = indexToOffset[indexType];
          if (!hasMore || nextOffset == null) {
            continue;
          }

          final builder = IndexSearchQueryBuilder(
            prefix: _meiliSearchService.prefix,
            indexType: indexType,
            query: state.query,
          )
            ..limit(pageSize)
            ..offset(nextOffset);

          // Apply filters for this index type
          final filterType = _mapIndexTypeToSearchFilterType(indexType);
          final selections = state.filtersByType[filterType];
          final filters = _buildFiltersForIndexType(indexType, selections);
          if (filters != null && filters.isNotEmpty) {
            builder.filters(filters);
          }

          // Apply nftTokens owner filter if needed
          if (indexType == MeiliSearchIndexType.nftTokens) {
            final ownerAddress =
                await injector<AddressService>().getAllAddresses();
            final addressFilter =
                IndexSearchQueryHelper.buildNftTokensOwnerFilter(ownerAddress);
            if (addressFilter != null) {
              final existingFilters = filters ?? <String>[];
              builder.filters([...existingFilters, addressFilter]);
            }
          }

          queries.add(builder.build());
        }

        if (queries.isEmpty) {
          emit(state.copyWith(isLoading: false));
          return;
        }

        final newResult = await _meiliSearchService.searchAll(queries: queries);

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

  List<String>? _buildSortForIndexType(
    MeiliSearchIndexType indexType,
    SearchSortOrder sortOrder,
  ) {
    switch (indexType) {
      case MeiliSearchIndexType.channels:
      case MeiliSearchIndexType.playlists:
        if (sortOrder == SearchSortOrder.aToZ) {
          return ['title:asc'];
        }
        return null;
      case MeiliSearchIndexType.playlistItems:
        // Items only support relevance for now.
        return null;
      case MeiliSearchIndexType.nftTokens:
        if (sortOrder == SearchSortOrder.aToZ) {
          return ['token_title:asc'];
        }
        // For recent we currently rely on backend/default ranking rules.
        return null;
    }
  }

  Future<void> _onFilterToggled(
    MeiliSearchFilterToggled event,
    Emitter<MeiliSearchState> emit,
  ) async {
    final updatedFiltersByType =
        Map<SearchFilterType, List<MeiliFilterSelection>>.from(
      state.filtersByType,
    );
    // Replace filters for this filterType with the new selections
    updatedFiltersByType[event.filterType] = event.selections;

    final updatedState = state.copyWith(filtersByType: updatedFiltersByType);
    emit(updatedState);

    // Re-run search for current filterType only
    final currentQuery = updatedState.query.trim();
    if (currentQuery.isEmpty || updatedState.result == null) {
      return;
    }

    try {
      final filterType = updatedState.filterType;
      final indexTypeToUpdate = _mapSearchFilterTypeToIndexType(filterType);

      int limit;
      switch (filterType) {
        case SearchFilterType.channels:
          limit = updatedState.result!.channels.items.length;
          break;
        case SearchFilterType.playlists:
          limit = updatedState.result!.playlists.items.length;
          break;
        case SearchFilterType.items:
          limit = updatedState.result!.works.items.length;
          break;
        case SearchFilterType.nftTokens:
          limit = updatedState.result!.nftTokens.items.length;
          break;
      }

      if (limit == 0) {
        return;
      }

      final builder = IndexSearchQueryBuilder(
        prefix: _meiliSearchService.prefix,
        indexType: indexTypeToUpdate,
        query: currentQuery,
      )
        ..limit(limit)
        ..offset(0);

      final sort =
          _buildSortForIndexType(indexTypeToUpdate, updatedState.sortOrder);
      if (sort != null && sort.isNotEmpty) {
        builder.sort(sort);
      }

      // Apply filters
      final filters = _buildFiltersForIndexType(
        indexTypeToUpdate,
        updatedState.filtersByType[event.filterType] ?? [],
      );
      if (filters != null && filters.isNotEmpty) {
        builder.filters(filters);
      }

      // Apply nftTokens owner filter if needed
      if (indexTypeToUpdate == MeiliSearchIndexType.nftTokens) {
        final ownerAddress = await injector<AddressService>().getAllAddresses();
        final addressFilter =
            IndexSearchQueryHelper.buildNftTokensOwnerFilter(ownerAddress);
        if (addressFilter != null) {
          final existingFilters = filters ?? <String>[];
          builder.filters([...existingFilters, addressFilter]);
        }
      }

      final newResultForType =
          await _meiliSearchService.searchAll(queries: [builder.build()]);

      MeiliSearchResult mergedResult;
      switch (filterType) {
        case SearchFilterType.channels:
          mergedResult = updatedState.result!.copyWith(
            channels: newResultForType.channels,
          );
          break;
        case SearchFilterType.playlists:
          mergedResult = updatedState.result!.copyWith(
            playlists: newResultForType.playlists,
          );
          break;
        case SearchFilterType.items:
          mergedResult = updatedState.result!.copyWith(
            works: newResultForType.works,
          );
          break;
        case SearchFilterType.nftTokens:
          mergedResult = updatedState.result!.copyWith(
            nftTokens: newResultForType.nftTokens,
          );
          break;
      }

      emit(updatedState.copyWith(result: mergedResult));
    } catch (e) {
      log.severe('MeiliSearch filter toggle error: $e');
      emit(
        updatedState.copyWith(
          hasError: true,
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  MeiliSearchIndexType _mapSearchFilterTypeToIndexType(
    SearchFilterType filterType,
  ) {
    switch (filterType) {
      case SearchFilterType.channels:
        return MeiliSearchIndexType.channels;
      case SearchFilterType.playlists:
        return MeiliSearchIndexType.playlists;
      case SearchFilterType.items:
        return MeiliSearchIndexType.playlistItems;
      case SearchFilterType.nftTokens:
        return MeiliSearchIndexType.nftTokens;
    }
  }

  SearchFilterType _mapIndexTypeToSearchFilterType(
    MeiliSearchIndexType indexType,
  ) {
    switch (indexType) {
      case MeiliSearchIndexType.channels:
        return SearchFilterType.channels;
      case MeiliSearchIndexType.playlists:
        return SearchFilterType.playlists;
      case MeiliSearchIndexType.playlistItems:
        return SearchFilterType.items;
      case MeiliSearchIndexType.nftTokens:
        return SearchFilterType.nftTokens;
    }
  }

  List<String>? _buildFiltersForIndexType(
    MeiliSearchIndexType indexType,
    List<MeiliFilterSelection>? selections,
  ) {
    if (selections == null || selections.isEmpty) {
      return null;
    }

    final supportedFilters = indexType.supportedFilters;
    final filterExpressions = <String>[];

    for (final selection in selections) {
      final filterBy = selection.filterBy;

      // Only process filters that are supported for this index
      if (!supportedFilters.contains(filterBy)) {
        continue;
      }

      if (selection.isEmpty) {
        continue;
      }

      final fieldName = filterBy.meiliFieldName;
      // Build OR conditions for multi-select values
      final conditions =
          selection.value.map((val) => '$fieldName = "$val"').toList();
      if (conditions.isNotEmpty) {
        filterExpressions.add('(${conditions.join(' OR ')})');
      }
    }

    // AND across different filter types
    if (filterExpressions.isEmpty) {
      return null;
    }

    return filterExpressions;
  }
}
