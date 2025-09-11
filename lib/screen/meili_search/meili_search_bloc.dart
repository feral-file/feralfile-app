//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:math' as math;

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
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
  final List<Artwork> artworks;
  final List<Exhibition> exhibitions;
  final List<AlumniAccount> artists;
  final List<AlumniAccount> curators;
  final List<FFSeries> series;
  // Highest ranking scores per section
  final double artworksTopScore;
  final double exhibitionsTopScore;
  final double artistsTopScore;
  final double curatorsTopScore;
  final double seriesTopScore;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final int totalHits;
  final bool hasMoreResults;

  MeiliSearchState({
    this.query = '',
    this.artworks = const [],
    this.exhibitions = const [],
    this.artists = const [],
    this.curators = const [],
    this.series = const [],
    this.artworksTopScore = 0.0,
    this.exhibitionsTopScore = 0.0,
    this.artistsTopScore = 0.0,
    this.curatorsTopScore = 0.0,
    this.seriesTopScore = 0.0,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.totalHits = 0,
    this.hasMoreResults = false,
  });

  MeiliSearchState copyWith({
    String? query,
    List<Artwork>? artworks,
    List<Exhibition>? exhibitions,
    List<AlumniAccount>? artists,
    List<AlumniAccount>? curators,
    List<FFSeries>? series,
    double? artworksTopScore,
    double? exhibitionsTopScore,
    double? artistsTopScore,
    double? curatorsTopScore,
    double? seriesTopScore,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    int? totalHits,
    bool? hasMoreResults,
  }) {
    return MeiliSearchState(
      query: query ?? this.query,
      artworks: artworks ?? this.artworks,
      exhibitions: exhibitions ?? this.exhibitions,
      artists: artists ?? this.artists,
      curators: curators ?? this.curators,
      series: series ?? this.series,
      artworksTopScore: artworksTopScore ?? this.artworksTopScore,
      exhibitionsTopScore: exhibitionsTopScore ?? this.exhibitionsTopScore,
      artistsTopScore: artistsTopScore ?? this.artistsTopScore,
      curatorsTopScore: curatorsTopScore ?? this.curatorsTopScore,
      seriesTopScore: seriesTopScore ?? this.seriesTopScore,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      totalHits: totalHits ?? this.totalHits,
      hasMoreResults: hasMoreResults ?? this.hasMoreResults,
    );
  }

  bool get hasResults =>
      artworks.isNotEmpty ||
      exhibitions.isNotEmpty ||
      artists.isNotEmpty ||
      curators.isNotEmpty ||
      series.isNotEmpty;

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
            artworks: result.artworks,
            exhibitions: result.exhibitions,
            artists: result.artists,
            curators: result.curators,
            series: result.series,
            artworksTopScore: _maxOrZero(result.artworksRankingScore),
            exhibitionsTopScore: _maxOrZero(result.exhibitionsRankingScore),
            artistsTopScore: _maxOrZero(result.artistsRankingScore),
            curatorsTopScore: _maxOrZero(result.curatorsRankingScore),
            seriesTopScore: _maxOrZero(result.seriesRankingScore),
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
