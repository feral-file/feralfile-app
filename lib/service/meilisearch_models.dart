//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
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

  /// Get the SearchFilterType that corresponds to this index result
  SearchFilterType get filterType;

  /// Get the list of available filter selections for this index type
  /// Extracts unique filter values from items based on supported filters
  /// Returns one MeiliFilterSelection for each supported filter with available values
  List<MeiliFilterSelection> getAvailableFilters() {
    final supportedFilters = filterType.supportedFilters;
    if (supportedFilters.isEmpty) {
      return [];
    }

    final filterSelections = <MeiliFilterSelection>[];

    for (final filterBy in supportedFilters) {
      final values = _extractFilterValues(filterBy);
      // Always create a MeiliFilterSelection for each supported filter,
      // even if values is empty (user can still see the filter option)
      filterSelections.add(
        MeiliFilterSelection(
          filterBy: filterBy,
          value: values,
        ),
      );
    }

    return filterSelections;
  }

  /// Extract unique filter values from items for a specific filter
  Set<String> _extractFilterValues(SearchFilterBy filterBy);
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

  @override
  SearchFilterType get filterType => SearchFilterType.channels;

  @override
  Set<String> _extractFilterValues(SearchFilterBy filterBy) {
    switch (filterBy) {
      case SearchFilterBy.curator:
        return _extractCuratorValues();
      case SearchFilterBy.publisher:
        return _extractPublisherValues();
      default:
        return {};
    }
  }

  Set<String> _extractCuratorValues() {
    final values = <String>{};
    for (final channel in items) {
      if (channel.curator != null && channel.curator!.isNotEmpty) {
        values.add(channel.curator!);
      }
    }
    return values;
  }

  Set<String> _extractPublisherValues() {
    // Publisher field not found in Channel model
    return {};
  }
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

  @override
  SearchFilterType get filterType => SearchFilterType.playlists;

  @override
  Set<String> _extractFilterValues(SearchFilterBy filterBy) {
    switch (filterBy) {
      case SearchFilterBy.dp1Version:
        return _extractDp1VersionValues();
      default:
        return {};
    }
  }

  Set<String> _extractDp1VersionValues() {
    final values = <String>{};
    for (final playlist in items) {
      if (playlist.dpVersion.isNotEmpty) {
        values.add(playlist.dpVersion);
      }
    }
    return values;
  }
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

  @override
  SearchFilterType get filterType => SearchFilterType.items;

  @override
  Set<String> _extractFilterValues(SearchFilterBy filterBy) {
    // Items don't support any filters
    return {};
  }
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

  @override
  SearchFilterType get filterType => SearchFilterType.nftTokens;

  @override
  Set<String> _extractFilterValues(SearchFilterBy filterBy) {
    switch (filterBy) {
      case SearchFilterBy.chain:
        return _extractChainValues();
      case SearchFilterBy.standard:
        return _extractStandardValues();
      case SearchFilterBy.artist:
        return _extractArtistValues();
      default:
        return {};
    }
  }

  Set<String> _extractChainValues() {
    final values = <String>{};
    for (final token in items) {
      if (token.chain.isNotEmpty) {
        values.add(token.chain);
      }
    }
    return values;
  }

  Set<String> _extractStandardValues() {
    final values = <String>{};
    for (final token in items) {
      if (token.standard.isNotEmpty) {
        values.add(token.standard);
      }
    }
    return values;
  }

  Set<String> _extractArtistValues() {
    final values = <String>{};
    for (final token in items) {
      // Extract all artist names from metadata
      if (token.metadata?.artists != null) {
        for (final artist in token.metadata!.artists!) {
          if (artist.name.isNotEmpty) {
            values.add(artist.name);
          }
        }
      }
      // Extract all artist names from enrichmentSource
      if (token.enrichmentSource?.artists != null) {
        for (final artist in token.enrichmentSource!.artists!) {
          if (artist.name.isNotEmpty) {
            values.add(artist.name);
          }
        }
      }
    }
    return values;
  }
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

  MeiliSearchResult copyWith({
    MeiliSearchChannelResult? channels,
    MeiliSearchPlaylistResult? playlists,
    MeiliSearchWorksResult? works,
    MeiliSearchNftTokensResult? nftTokens,
  }) {
    return MeiliSearchResult(
      channels: channels ?? this.channels,
      playlists: playlists ?? this.playlists,
      works: works ?? this.works,
      nftTokens: nftTokens ?? this.nftTokens,
    );
  }
}
