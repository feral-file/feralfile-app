//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:math' as math;

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:autonomy_flutter/util/latest_async.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class MeiliSearchEvent {}

class MeiliSearchQueryChanged extends MeiliSearchEvent {
  final String query;

  MeiliSearchQueryChanged(this.query);
}

class MeiliSearchCleared extends MeiliSearchEvent {}

class MeiliSearchLoadMore extends MeiliSearchEvent {}

class MeiliSearchState {
  final String query;
  final List<Channel> channels;
  final List<DP1Call> playlists;
  final List<DP1Item> items;
  // Highest ranking scores per section
  final double channelsTopScore;
  final double playlistsTopScore;
  final double itemsTopScore;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final int totalHits;
  final bool hasMoreResults;

  MeiliSearchState({
    this.query = '',
    this.channels = const [],
    this.playlists = const [],
    this.items = const [],
    this.channelsTopScore = 0.0,
    this.playlistsTopScore = 0.0,
    this.itemsTopScore = 0.0,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.totalHits = 0,
    this.hasMoreResults = false,
  });

  MeiliSearchState copyWith({
    String? query,
    List<Channel>? channels,
    List<DP1Call>? playlists,
    List<DP1Item>? items,
    double? channelsTopScore,
    double? playlistsTopScore,
    double? itemsTopScore,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    int? totalHits,
    bool? hasMoreResults,
  }) {
    return MeiliSearchState(
      query: query ?? this.query,
      channels: channels ?? this.channels,
      playlists: playlists ?? this.playlists,
      items: items ?? this.items,
      channelsTopScore: channelsTopScore ?? this.channelsTopScore,
      playlistsTopScore: playlistsTopScore ?? this.playlistsTopScore,
      itemsTopScore: itemsTopScore ?? this.itemsTopScore,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      totalHits: totalHits ?? this.totalHits,
      hasMoreResults: hasMoreResults ?? this.hasMoreResults,
    );
  }

  bool get hasResults =>
      channels.isNotEmpty || playlists.isNotEmpty || items.isNotEmpty;

  bool get isEmpty => !hasResults && !isLoading && query.isNotEmpty;
}

class MeiliSearchBloc extends AuBloc<MeiliSearchEvent, MeiliSearchState> {
  final MeiliSearchService _meiliSearchService;
  static const int _pageSize = 5;
  int _currentOffset = 0;
  final LatestAsync<MeiliSearchResult> _latestSearch =
      LatestAsync<MeiliSearchResult>();

  MeiliSearchBloc(this._meiliSearchService) : super(MeiliSearchState()) {
    on<MeiliSearchQueryChanged>(_onQueryChanged);
    on<MeiliSearchCleared>(_onCleared);
    // on<MeiliSearchLoadMore>(_onLoadMore);
  }

  @override
  void add(MeiliSearchEvent event) {
    log.info('MeiliSearchBloc event: $event');
    super.add(event);
  }

  Future<void> _onQueryChanged(
    MeiliSearchQueryChanged event,
    Emitter<MeiliSearchState> emit,
  ) async {
    final start = DateTime.now();
    emit(state.copyWith(
      query: event.query,
      isLoading: true,
      hasError: false,
      errorMessage: null,
    ));

    try {
      _currentOffset = 0;
      // Use empty string for query to get all data when no search text is provided
      final searchQuery = event.query.trim().isEmpty ? '' : event.query;
      await _latestSearch.run(
        () async => _meiliSearchService.searchAll(
          text: searchQuery,
          limit: _pageSize,
          offset: _currentOffset,
        ),
        onData: (result) {
          double _maxOrZero(List<double> values) =>
              values.isEmpty ? 0.0 : values.reduce(math.max);

          emit(state.copyWith(
            channels: result.channels,
            playlists: result.playlists,
            items: result.items,
            channelsTopScore: _maxOrZero(result.channelsRankingScore),
            playlistsTopScore: _maxOrZero(result.playlistsRankingScore),
            itemsTopScore: _maxOrZero(result.itemsRankingScore),
            isLoading: false,
            totalHits: result.totalHits,
            hasMoreResults: result.totalHits > _pageSize,
          ));

          final duration = DateTime.now().difference(start);
          log.info(
              '_onQueryChanged MeiliSearch query "${event.query}" took ${duration.inMilliseconds} ms');

          _currentOffset = _pageSize;
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

    log.info('_onQueryChanged MeiliSearch finished');
  }

  Future<void> _onCleared(
    MeiliSearchCleared event,
    Emitter<MeiliSearchState> emit,
  ) async {
    emit(MeiliSearchState());
  }
}
