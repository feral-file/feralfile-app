import 'dart:math';

import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meilisearch/meilisearch.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_channel_data.dart';
import '../mock_data/mock_dp1_item_data.dart';
import '../mock_data/mock_playlist_data.dart';
import 'mock_injector/mock_injector.dart';
import 'mocks/meilisearch_mock_data.dart';
import 'mocks/meilisearch_mocks.dart';

void main() {
  setUpAll(() async {
    await dotenv.load();
    MockInjector.setup();
  });

// initialize function tests
  group('MeiliSearchService Initialize Tests', () {
    test('should initialize the service', () {
      final service = MeiliSearchService();
      // expect no error
      expect(() => service.initialize(), returnsNormally);
    });
  });

  // search all function tests
  group('MeiliSearchService Tests', () {
    late MeiliSearchService service;
    late MockMeiliSearchClient mockClient;

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(MockMultiSearchQuery());
    });

    setUp(() {
      mockClient = MockMeiliSearchClient();
      service = MeiliSearchService(testClient: mockClient);
      service.initialize();
    });

    tearDown(() {
      resetMocktailState();
    });

    group('Search Functionality Tests', () {
      test('should search with single text query', () async {
        // Arrange
        final channels = MockChannelData.createList();
        final playlists = MockPlaylistData.createList();
        final items = MockDP1ItemData.createList();
        final mockMultiResult = MeiliSearchMockData.getBaseSearchResult(
          channels: channels,
          playlists: playlists,
          items: items,
        );

        when(() => mockClient.multiSearch(any()))
            .thenAnswer((_) async => mockMultiResult);

        // Act
        final result = await service.searchAll(texts: ['test query']);

        // Assert
        expect(result.channels, hasLength(channels.length));
        expect(result.playlists, hasLength(playlists.length));
        expect(result.items, hasLength(items.length));
        expect(result.totalHits,
            equals(channels.length + playlists.length + items.length));

        // Verify interactions
        verify(() => mockClient.multiSearch(any())).called(1);
      });

      test('should search with multiple text queries', () async {
        // Arrange
        final channels = MockChannelData.createList();
        final playlists = MockPlaylistData.createList();
        final items = MockDP1ItemData.createList();
        final mockMultiResult = MeiliSearchMockData.getBaseSearchResult(
          channels: channels,
          playlists: playlists,
          items: items,
        );

        when(() => mockClient.multiSearch(any()))
            .thenAnswer((_) async => mockMultiResult);

        // Act
        final result = await service.searchAll(texts: ['query1', 'query2']);

        // Assert
        expect(result.channels, hasLength(channels.length));
        expect(result.playlists, hasLength(playlists.length));
        expect(result.items, hasLength(items.length));
        expect(result.totalHits,
            equals(channels.length + playlists.length + items.length));
        verify(() => mockClient.multiSearch(any())).called(1);
      });

      test('should handle empty text list', () async {
        // Arrange

        final emptyMockMultiResult = MeiliSearchMockData.getEmptySearchResult();
        when(() => mockClient.multiSearch(any()))
            .thenAnswer((_) async => emptyMockMultiResult);

        // Act
        final result = await service.searchAll(texts: []);

        // Assert
        expect(result.channels, hasLength(0));
        expect(result.playlists, hasLength(0));
        expect(result.items, hasLength(0));
        expect(result.totalHits, equals(0));
        verify(() => mockClient.multiSearch(any())).called(1);
      });

      test('should trim whitespace from queries', () async {
        // Arrange
        final channels = MockChannelData.createList();
        final playlists = MockPlaylistData.createList();
        final items = MockDP1ItemData.createList();
        final mockMultiResult = MeiliSearchMockData.getBaseSearchResult(
          channels: channels,
          playlists: playlists,
          items: items,
        );
        when(() => mockClient.multiSearch(any(
                that: predicate<MultiSearchQuery>(
              (q) =>
                  q.queries.every((query) => query.query == 'query') &&
                  q.queries.length == 3,
            )))).thenAnswer((_) async => mockMultiResult);
        // Act
        final result = await service.searchAll(texts: ['  query  ']);

        // Assert
        expect(result.channels, hasLength(channels.length));
        expect(result.playlists, hasLength(playlists.length));
        expect(result.items, hasLength(items.length));
        expect(result.totalHits,
            equals(channels.length + playlists.length + items.length));
        verify(() => mockClient.multiSearch(any())).called(1);
      });

      test('should sort results by score descending', () async {
        // Arrange
        final channels = MockChannelData.createList(count: 20);
        final playlists = MockPlaylistData.createList(count: 20);
        final items = MockDP1ItemData.createList(count: 20);

        final mockMultiResult = MeiliSearchMockData.getBaseSearchResult(
          channels: channels,
          playlists: playlists,
          items: items,
        );

        when(() => mockClient.multiSearch(any()))
            .thenAnswer((_) async => mockMultiResult);

        // Act
        final result = await service.searchAll(texts: ['test']);

        // Assert
        expect(result.channelsRankingScore.isSorted((a, b) => b.compareTo(a)),
            isTrue);
        expect(result.playlistsRankingScore.isSorted((a, b) => b.compareTo(a)),
            isTrue);
        expect(result.itemsRankingScore.isSorted((a, b) => b.compareTo(a)),
            isTrue);

        // Verify interactions
        verify(() => mockClient.multiSearch(any())).called(1);
      });

      test('should remove duplicated', () async {
        final channels = MockChannelData.createList(count: 20);
        final playlists = MockPlaylistData.createList(count: 20);
        final items = MockDP1ItemData.createList(count: 20);

        final mockMultiResult = MeiliSearchMockData.getBaseSearchResult(
          channels: channels + channels,
          playlists: playlists + playlists,
          items: items + items,
        );

        when(() => mockClient.multiSearch(any()))
            .thenAnswer((_) async => mockMultiResult);

        // Act
        final result = await service.searchAll(texts: ['test']);

        // Assert
        expect(result.channels, hasLength(channels.removeDuplicates().length));
        expect(
            result.playlists, hasLength(playlists.removeDuplicates().length));
        expect(result.items, hasLength(items.removeDuplicates().length));
        verify(() => mockClient.multiSearch(any())).called(1);
      });
    });

    // group('Edge Cases Tests', () {
    //   test('should handle empty search results', () {
    //     // Test when all indexes return empty results
    //   });

    //   test('should handle partial results', () {
    //     // Test when only some indexes return results
    //   });

    //   test('should handle missing ranking scores', () {
    //     // Test when ranking scores are null or missing
    //   });

    //   test('should handle malformed JSON responses', () {
    //     // Test invalid JSON handling
    //   });

    //   test('should handle missing fields in results', () {
    //     // Test missing field handling
    //   });
    // });
  });
}

extension ListExtension<T> on List<T> {
  bool isSorted(int Function(T a, T b) compare) {
    for (int i = 0; i < length - 1; i++) {
      if (compare(this[i], this[i + 1]) > 0) {
        return false;
      }
    }
    return true;
  }
}
