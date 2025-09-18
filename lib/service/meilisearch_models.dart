//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

/// Result class for MeiliSearch operations
class MeiliSearchResult {
  final List<Channel> channels;
  final List<DP1Call> playlists;
  final List<DP1Item> items;
  // Ranking scores from MeiliSearch (_rankingScore)
  final List<double> channelsRankingScore;
  final List<double> playlistsRankingScore;
  final List<double> itemsRankingScore;
  final int totalHits;
  final int processingTimeMs;

  MeiliSearchResult({
    required this.channels,
    required this.playlists,
    required this.items,
    this.channelsRankingScore = const [],
    this.playlistsRankingScore = const [],
    this.itemsRankingScore = const [],
    required this.totalHits,
    required this.processingTimeMs,
  });

  factory MeiliSearchResult.empty() => MeiliSearchResult(
        channels: [],
        playlists: [],
        items: [],
        channelsRankingScore: const [],
        playlistsRankingScore: const [],
        itemsRankingScore: const [],
        totalHits: 0,
        processingTimeMs: 0,
      );
}
