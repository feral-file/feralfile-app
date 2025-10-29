// Mock data factory for MeiliSearch test responses
import 'dart:math';

import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:mocktail/mocktail.dart';
import '../../mock_data/mock_channel_data.dart';
import '../../mock_data/mock_playlist_data.dart';
import '../../mock_data/mock_dp1_item_data.dart';
import 'meilisearch_mocks.dart';

class MeiliSearchMockData {
  static MockMultiSearchResult getEmptySearchResult() {
    final emptyMockMultiResult = MockMultiSearchResult();
    when(() => emptyMockMultiResult.results).thenReturn([]);
    return emptyMockMultiResult;
  }

  static MockMultiSearchResult getBaseSearchResultWithRankingScores({
    List<Pair<Channel, double>>? channelsWithScores,
    List<Pair<DP1Call, double>>? playlistsWithScores,
    List<Pair<DP1Item, double>>? itemsWithScores,
  }) {
    final channels = channelsWithScores ?? [];
    final playlists = playlistsWithScores ?? [];
    final items = itemsWithScores ?? [];

    final channelHits = channels
        .map((e) =>
            createChannelSearchResult(channel: e.first, rankingScore: e.second))
        .toList();
    final playlistHits = playlists
        .map((e) => createPlaylistSearchResult(
            playlist: e.first, rankingScore: e.second))
        .toList();
    final itemHits = items
        .map((e) =>
            createItemSearchResult(item: e.first, rankingScore: e.second))
        .toList();

    final mockChannelResult = MockSearchResult();
    when(() => mockChannelResult.hits).thenReturn(channelHits);
    when(() => mockChannelResult.indexUid).thenReturn('feed_prod_channels');
    when(() => mockChannelResult.processingTimeMs).thenReturn(5);

    final mockPlaylistResult = MockSearchResult();
    when(() => mockPlaylistResult.hits).thenReturn(playlistHits);
    when(() => mockPlaylistResult.indexUid).thenReturn('feed_prod_playlists');
    when(() => mockPlaylistResult.processingTimeMs).thenReturn(8);

    final mockItemResult = MockSearchResult();
    when(() => mockItemResult.hits).thenReturn(itemHits);
    when(() => mockItemResult.indexUid).thenReturn('feed_prod_playlist_items');
    when(() => mockItemResult.processingTimeMs).thenReturn(6);

    final mockMultiResult = MockMultiSearchResult();
    when(() => mockMultiResult.results).thenReturn([
      mockChannelResult,
      mockPlaylistResult,
      mockItemResult,
    ]);
    return mockMultiResult;
  }

  static MockMultiSearchResult getBaseSearchResult({
    List<Channel>? channels,
    List<DP1Call>? playlists,
    List<DP1Item>? items,
  }) {
    // random from 0 to 1
    final random = Random();

    final channelPairs =
        channels?.map((e) => Pair(e, random.nextDouble())).toList();
    final playlistPairs =
        playlists?.map((e) => Pair(e, random.nextDouble())).toList();
    final itemPairs = items?.map((e) => Pair(e, random.nextDouble())).toList();

    return getBaseSearchResultWithRankingScores(
      channelsWithScores: channelPairs,
      playlistsWithScores: playlistPairs,
      itemsWithScores: itemPairs,
    );
  }

  // Create search result wrapper for channels
  static Map<String, dynamic> createChannelSearchResult({
    required Channel channel,
    double rankingScore = 0.95,
  }) {
    return {
      '_rankingScore': rankingScore,
      'channel': channel.toJson(),
    };
  }

  // Create search result wrapper for playlists
  static Map<String, dynamic> createPlaylistSearchResult({
    required DP1Call playlist,
    double rankingScore = 0.85,
  }) {
    return {
      '_rankingScore': rankingScore,
      'playlist': playlist.toJson(),
    };
  }

  // Create search result wrapper for items
  static Map<String, dynamic> createItemSearchResult({
    required DP1Item item,
    double rankingScore = 0.75,
  }) {
    return {
      '_rankingScore': rankingScore,
      'playlistItem': item.toJson(),
    };
  }

  // Create list of channel search results
  static List<Map<String, dynamic>> createChannelSearchResults({
    List<Channel>? channels,
    List<double>? rankingScores,
  }) {
    final channelList = channels ?? MockChannelData.createList();
    final scores = rankingScores ??
        List.generate(channelList.length, (index) => 0.95 - (index * 0.05));

    return channelList.asMap().entries.map((entry) {
      final index = entry.key;
      final channel = entry.value;
      return createChannelSearchResult(
        channel: channel,
        rankingScore: scores[index],
      );
    }).toList();
  }

  // Create list of playlist search results
  static List<Map<String, dynamic>> createPlaylistSearchResults({
    List<DP1Call>? playlists,
    List<double>? rankingScores,
  }) {
    final playlistList = playlists ?? MockPlaylistData.createList();
    final scores = rankingScores ??
        List.generate(playlistList.length, (index) => 0.90 - (index * 0.05));

    return playlistList.asMap().entries.map((entry) {
      final index = entry.key;
      final playlist = entry.value;
      return createPlaylistSearchResult(
        playlist: playlist,
        rankingScore: scores[index],
      );
    }).toList();
  }

  // Create list of item search results
  static List<Map<String, dynamic>> createItemSearchResults({
    List<DP1Item>? items,
    List<double>? rankingScores,
  }) {
    final itemList = items ?? MockDP1ItemData.createList();
    final scores = rankingScores ??
        List.generate(itemList.length, (index) => 0.88 - (index * 0.05));

    return itemList.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return createItemSearchResult(
        item: item,
        rankingScore: scores[index],
      );
    }).toList();
  }

  // Create empty search results
  static List<Map<String, dynamic>> createEmptySearchResults() => [];

  // Create single channel search result
  static List<Map<String, dynamic>> createSingleChannelSearchResult({
    Channel? channel,
    double rankingScore = 0.95,
  }) {
    final channelObj = channel ?? MockChannelData.createSingle();
    return [
      createChannelSearchResult(channel: channelObj, rankingScore: rankingScore)
    ];
  }

  // Create single playlist search result
  static List<Map<String, dynamic>> createSinglePlaylistSearchResult({
    DP1Call? playlist,
    double rankingScore = 0.90,
  }) {
    final playlistObj = playlist ?? MockPlaylistData.createSingle();
    return [
      createPlaylistSearchResult(
          playlist: playlistObj, rankingScore: rankingScore)
    ];
  }

  // Create single item search result
  static List<Map<String, dynamic>> createSingleItemSearchResult({
    DP1Item? item,
    double rankingScore = 0.85,
  }) {
    final itemObj = item ?? MockDP1ItemData.createSingle();
    return [createItemSearchResult(item: itemObj, rankingScore: rankingScore)];
  }

  // Create mixed search results (channels, playlists, items)
  static List<Map<String, dynamic>> createMixedSearchResults({
    List<Channel>? channels,
    List<DP1Call>? playlists,
    List<DP1Item>? items,
    List<double>? channelScores,
    List<double>? playlistScores,
    List<double>? itemScores,
  }) {
    final results = <Map<String, dynamic>>[];

    // Add channel results
    if (channels != null && channels.isNotEmpty) {
      results.addAll(createChannelSearchResults(
        channels: channels,
        rankingScores: channelScores,
      ));
    }

    // Add playlist results
    if (playlists != null && playlists.isNotEmpty) {
      results.addAll(createPlaylistSearchResults(
        playlists: playlists,
        rankingScores: playlistScores,
      ));
    }

    // Add item results
    if (items != null && items.isNotEmpty) {
      results.addAll(createItemSearchResults(
        items: items,
        rankingScores: itemScores,
      ));
    }

    return results;
  }

  // Create search results with specific ranking order
  static List<Map<String, dynamic>> createRankedSearchResults({
    required List<dynamic> objects,
    required String objectType,
    List<double>? rankingScores,
  }) {
    final scores = rankingScores ??
        List.generate(objects.length, (index) => 1.0 - (index * 0.1));

    return objects.asMap().entries.map((entry) {
      final index = entry.key;
      final obj = entry.value;

      switch (objectType) {
        case 'channel':
          return createChannelSearchResult(
            channel: obj as Channel,
            rankingScore: scores[index],
          );
        case 'playlist':
          return createPlaylistSearchResult(
            playlist: obj as DP1Call,
            rankingScore: scores[index],
          );
        case 'item':
          return createItemSearchResult(
            item: obj as DP1Item,
            rankingScore: scores[index],
          );
        default:
          throw ArgumentError('Unknown object type: $objectType');
      }
    }).toList();
  }

  // Create search results with high ranking scores
  static List<Map<String, dynamic>> createHighRankingSearchResults({
    required List<dynamic> objects,
    required String objectType,
  }) {
    return createRankedSearchResults(
      objects: objects,
      objectType: objectType,
      rankingScores:
          List.generate(objects.length, (index) => 0.95 + (index * 0.01)),
    );
  }

  // Create search results with low ranking scores
  static List<Map<String, dynamic>> createLowRankingSearchResults({
    required List<dynamic> objects,
    required String objectType,
  }) {
    return createRankedSearchResults(
      objects: objects,
      objectType: objectType,
      rankingScores:
          List.generate(objects.length, (index) => 0.1 + (index * 0.01)),
    );
  }

  // Helper method to create search results from any object type
  static Map<String, dynamic> createSearchResultFromObject({
    required dynamic object,
    required String objectKey,
    double rankingScore = 0.95,
  }) {
    Map<String, dynamic> objectJson;

    if (object is Map<String, dynamic>) {
      objectJson = object;
    } else {
      // Try to call toJson() method
      try {
        objectJson = (object as dynamic).toJson() as Map<String, dynamic>;
      } catch (e) {
        // Fallback to toString representation
        objectJson = {'id': object.toString()};
      }
    }

    return {
      '_rankingScore': rankingScore,
      objectKey: objectJson,
    };
  }
}
