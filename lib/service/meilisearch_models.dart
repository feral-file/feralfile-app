//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/ff_series.dart';

/// Result class for MeiliSearch operations
class MeiliSearchResult {
  final List<Artwork> artworks;
  final List<Exhibition> exhibitions;
  final List<AlumniAccount> artists;
  final List<AlumniAccount> curators;
  final List<FFSeries> series;
  // Ranking scores from MeiliSearch (_rankingScore)
  final List<double> artworksRankingScore;
  final List<double> exhibitionsRankingScore;
  final List<double> artistsRankingScore;
  final List<double> curatorsRankingScore;
  final List<double> seriesRankingScore;
  final int totalHits;
  final int processingTimeMs;

  MeiliSearchResult({
    required this.artworks,
    required this.exhibitions,
    required this.artists,
    required this.curators,
    required this.series,
    this.artworksRankingScore = const [],
    this.exhibitionsRankingScore = const [],
    this.artistsRankingScore = const [],
    this.curatorsRankingScore = const [],
    this.seriesRankingScore = const [],
    required this.totalHits,
    required this.processingTimeMs,
  });

  factory MeiliSearchResult.empty() => MeiliSearchResult(
        artworks: [],
        exhibitions: [],
        artists: [],
        curators: [],
        series: [],
        artworksRankingScore: const [],
        exhibitionsRankingScore: const [],
        artistsRankingScore: const [],
        curatorsRankingScore: const [],
        seriesRankingScore: const [],
        totalHits: 0,
        processingTimeMs: 0,
      );
}
