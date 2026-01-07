//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

/// Abstract base class for MeiliSearch index results
abstract class MeiliSearchIndexResult<T> {
  final List<T> items;
  final double maxRankingScore;
  final int totalHits;
  final int offset;

  MeiliSearchIndexResult({
    required this.items,
    required this.maxRankingScore,
    required this.totalHits,
    required this.offset,
  });
}

/// Result for Channel index
class MeiliSearchChannelResult extends MeiliSearchIndexResult<Channel> {
  MeiliSearchChannelResult({
    required super.items,
    required super.maxRankingScore,
    required super.totalHits,
    required super.offset,
  });

  factory MeiliSearchChannelResult.empty() => MeiliSearchChannelResult(
        items: [],
        maxRankingScore: 0.0,
        totalHits: 0,
        offset: 0,
      );
}

/// Result for Playlist index
class MeiliSearchPlaylistResult extends MeiliSearchIndexResult<DP1Call> {
  MeiliSearchPlaylistResult({
    required super.items,
    required super.maxRankingScore,
    required super.totalHits,
    required super.offset,
  });

  factory MeiliSearchPlaylistResult.empty() => MeiliSearchPlaylistResult(
        items: [],
        maxRankingScore: 0.0,
        totalHits: 0,
        offset: 0,
      );
}

/// Result for Works (playlist items) index
class MeiliSearchWorksResult extends MeiliSearchIndexResult<DP1Item> {
  MeiliSearchWorksResult({
    required super.items,
    required super.maxRankingScore,
    required super.totalHits,
    required super.offset,
  });

  factory MeiliSearchWorksResult.empty() => MeiliSearchWorksResult(
        items: [],
        maxRankingScore: 0.0,
        totalHits: 0,
        offset: 0,
      );
}

/// Result for NFT Tokens index
class MeiliSearchNftTokensResult extends MeiliSearchIndexResult<AssetToken> {
  MeiliSearchNftTokensResult({
    required super.items,
    required super.maxRankingScore,
    required super.totalHits,
    required super.offset,
  });

  factory MeiliSearchNftTokensResult.empty() => MeiliSearchNftTokensResult(
        items: [],
        maxRankingScore: 0.0,
        totalHits: 0,
        offset: 0,
      );
}

/// Result class for MeiliSearch operations
class MeiliSearchResult {
  final MeiliSearchChannelResult channels;
  final MeiliSearchPlaylistResult playlists;
  final MeiliSearchWorksResult works;
  final MeiliSearchNftTokensResult nftTokens;

  MeiliSearchResult({
    required this.channels,
    required this.playlists,
    required this.works,
    required this.nftTokens,
  });

  factory MeiliSearchResult.empty() => MeiliSearchResult(
        channels: MeiliSearchChannelResult.empty(),
        playlists: MeiliSearchPlaylistResult.empty(),
        works: MeiliSearchWorksResult.empty(),
        nftTokens: MeiliSearchNftTokensResult.empty(),
      );

  /// Get total hits across all indexes
  int get totalHits =>
      channels.totalHits +
      playlists.totalHits +
      works.totalHits +
      nftTokens.totalHits;
}
