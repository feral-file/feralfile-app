//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMeiliSearchService extends Mock implements MeiliSearchService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMeiliSearchService mockService;
  late MeiliSearchBloc bloc;

  setUp(() {
    mockService = _MockMeiliSearchService();
    bloc = MeiliSearchBloc(mockService);
  });

  tearDown(() async {
    await bloc.close();
  });

  group('MeiliSearchPage Integration Tests', () {
    group('Search Functionality', () {
      test('successfully searches and returns all result types', () async {
        final channels = [
          Channel(
            id: 'c1',
            title: 'Channel One',
            slug: 'channel-one',
            created: DateTime(2025, 1, 1),
            playlists: const <String>[],
          ),
        ];
        final playlists = [
          DP1Call(
            dpVersion: '1.0.0',
            id: 'p1',
            slug: 'playlist-one',
            title: 'Playlist One',
            created: DateTime(2025, 1, 2),
            items: const <DP1Item>[],
            signature: '0xabc',
          ),
        ];
        final items = [
          DP1Item(
            id: 'i1',
            duration: 60,
            title: 'Work One',
          ),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: channels,
              playlists: playlists,
              items: items,
              channelsRankingScore: const [0.9],
              playlistsRankingScore: const [0.8],
              itemsRankingScore: const [0.7],
              totalHits: 3,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['test query']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channels.length, equals(1));
        expect(bloc.state.playlists.length, equals(1));
        expect(bloc.state.items.length, equals(1));
        expect(bloc.state.totalHits, equals(3));
        expect(bloc.state.hasResults, isTrue);
        expect(bloc.state.hasError, isFalse);
      });

      test('returns empty results when no matches found', () async {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult.empty());

        bloc.add(MeiliSearchQueryChanged(const ['nonexistent']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.hasResults, isFalse);
        expect(bloc.state.isEmpty, isTrue);
        expect(bloc.state.query, equals('nonexistent'));
        expect(bloc.state.totalHits, equals(0));
      });

      test('handles search errors correctly', () async {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenThrow(Exception('Network error'));

        bloc.add(MeiliSearchQueryChanged(const ['test']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.hasError, isTrue);
        expect(bloc.state.errorMessage, contains('Network error'));
        expect(bloc.state.hasResults, isFalse);
      });
    });

    group('Ranking Score Ordering', () {
      test('stores ranking scores correctly', () async {
        final channels = [
          Channel(
            id: 'c1',
            title: 'High Score Channel',
            slug: 'high-score',
            created: DateTime(2025, 1, 1),
            playlists: const <String>[],
          ),
        ];
        final playlists = [
          DP1Call(
            dpVersion: '1.0.0',
            id: 'p1',
            slug: 'medium-score',
            title: 'Medium Score Playlist',
            created: DateTime(2025, 1, 2),
            items: const <DP1Item>[],
            signature: '0xabc',
          ),
        ];
        final items = [
          DP1Item(id: 'i1', duration: 60, title: 'Low Score Item'),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: channels,
              playlists: playlists,
              items: items,
              channelsRankingScore: const [0.95],
              playlistsRankingScore: const [0.7],
              itemsRankingScore: const [0.5],
              totalHits: 3,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['test']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channelsTopScore, equals(0.95));
        expect(bloc.state.playlistsTopScore, equals(0.7));
        expect(bloc.state.itemsTopScore, equals(0.5));

        // Verify ordering: channels > playlists > items
        expect(bloc.state.channelsTopScore, greaterThan(bloc.state.playlistsTopScore));
        expect(bloc.state.playlistsTopScore, greaterThan(bloc.state.itemsTopScore));
      });

      test('handles zero ranking scores', () async {
        final channels = [
          Channel(
            id: 'c1',
            title: 'Zero Score Channel',
            slug: 'zero-score',
            created: DateTime(2025, 1, 1),
            playlists: const <String>[],
          ),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: channels,
              playlists: const [],
              items: const [],
              channelsRankingScore: const [0.0],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['test']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channelsTopScore, equals(0.0));
        expect(bloc.state.hasResults, isTrue);
      });
    });

    group('Multiple Result Types', () {
      test('handles only channels results', () async {
        final channels = [
          Channel(
            id: 'c1',
            title: 'Channel One',
            slug: 'channel-one',
            created: DateTime(2025, 1, 1),
            playlists: const <String>[],
          ),
          Channel(
            id: 'c2',
            title: 'Channel Two',
            slug: 'channel-two',
            created: DateTime(2025, 1, 2),
            playlists: const <String>[],
          ),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: channels,
              playlists: const [],
              items: const [],
              channelsRankingScore: const [0.9, 0.8],
              totalHits: 2,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['channels']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channels.length, equals(2));
        expect(bloc.state.playlists.length, equals(0));
        expect(bloc.state.items.length, equals(0));
        expect(bloc.state.hasResults, isTrue);
      });

      test('handles only playlists results', () async {
        final playlists = [
          DP1Call(
            dpVersion: '1.0.0',
            id: 'p1',
            slug: 'playlist-one',
            title: 'Playlist One',
            created: DateTime(2025, 1, 1),
            items: const <DP1Item>[],
            signature: '0xabc',
          ),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: const [],
              playlists: playlists,
              items: const [],
              playlistsRankingScore: const [0.85],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['playlists']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channels.length, equals(0));
        expect(bloc.state.playlists.length, equals(1));
        expect(bloc.state.items.length, equals(0));
        expect(bloc.state.hasResults, isTrue);
      });

      test('handles only items results', () async {
        final items = [
          DP1Item(id: 'i1', duration: 60, title: 'Artwork One'),
          DP1Item(id: 'i2', duration: 120, title: 'Artwork Two'),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: const [],
              playlists: const [],
              items: items,
              itemsRankingScore: const [0.92, 0.88],
              totalHits: 2,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['items']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channels.length, equals(0));
        expect(bloc.state.playlists.length, equals(0));
        expect(bloc.state.items.length, equals(2));
        expect(bloc.state.hasResults, isTrue);
      });
    });

    group('Multiple Query Handling', () {
      test('handles multiple search terms correctly', () async {
        final channels = [
          Channel(
            id: 'c1',
            title: 'Generative Art Channel',
            slug: 'generative-art',
            created: DateTime(2025, 1, 1),
            playlists: const <String>[],
          ),
        ];

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: channels,
              playlists: const [],
              items: const [],
              channelsRankingScore: const [0.95],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['generative', 'art']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.query, equals('generative art'));
        expect(bloc.state.hasResults, isTrue);
        verify(() => mockService.searchAll(
              texts: ['generative', 'art'],
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).called(1);
      });

      test('updates results when query changes', () async {
        // First search
        when(() => mockService.searchAll(
              texts: ['first'],
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: [
                Channel(
                  id: 'c1',
                  title: 'First Channel',
                  slug: 'first',
                  created: DateTime(2025, 1, 1),
                  playlists: const <String>[],
                ),
              ],
              playlists: const [],
              items: const [],
              channelsRankingScore: const [0.9],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        // Second search
        when(() => mockService.searchAll(
              texts: ['second'],
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: const [],
              playlists: [
                DP1Call(
                  dpVersion: '1.0.0',
                  id: 'p1',
                  slug: 'second',
                  title: 'Second Playlist',
                  created: DateTime(2025, 1, 2),
                  items: const <DP1Item>[],
                  signature: '0xabc',
                ),
              ],
              items: const [],
              playlistsRankingScore: const [0.8],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        // First query
        bloc.add(MeiliSearchQueryChanged(const ['first']));
        await bloc.stream.firstWhere((state) => !state.isLoading && state.query == 'first');

        expect(bloc.state.channels.length, equals(1));
        expect(bloc.state.playlists.length, equals(0));

        // Second query
        bloc.add(MeiliSearchQueryChanged(const ['second']));
        await bloc.stream.firstWhere((state) => !state.isLoading && state.query == 'second');

        expect(bloc.state.channels.length, equals(0));
        expect(bloc.state.playlists.length, equals(1));
      });
    });

    group('State Management', () {
      test('maintains correct loading state transitions', () async {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return MeiliSearchResult.empty();
        });

        expect(bloc.state.isLoading, isFalse);

        bloc.add(MeiliSearchQueryChanged(const ['test']));

        // Should transition to loading
        await bloc.stream.firstWhere((state) => state.isLoading);
        expect(bloc.state.isLoading, isTrue);

        // Should complete loading
        await bloc.stream.firstWhere((state) => !state.isLoading);
        expect(bloc.state.isLoading, isFalse);
      });

      test('recovers from error on successful search', () async {
        // First call fails
        when(() => mockService.searchAll(
              texts: ['test'],
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenThrow(Exception('Network error'));

        bloc.add(MeiliSearchQueryChanged(const ['test']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.hasError, isTrue);
        expect(bloc.state.hasResults, isFalse);

        // Second call with different query succeeds
        when(() => mockService.searchAll(
              texts: ['retry'],
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: [
                Channel(
                  id: 'c1',
                  title: 'Success Channel',
                  slug: 'success',
                  created: DateTime(2025, 1, 1),
                  playlists: const <String>[],
                ),
              ],
              playlists: const [],
              items: const [],
              channelsRankingScore: const [0.9],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['retry']));
        await bloc.stream.firstWhere((state) => !state.isLoading && state.query == 'retry');

        // After successful search, error should be cleared and results should be present
        expect(bloc.state.hasError, isFalse);
        expect(bloc.state.hasResults, isTrue);
        expect(bloc.state.channels.length, equals(1));
      });

      test('handles cleared state', () async {
        // First populate with data
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: [
                Channel(
                  id: 'c1',
                  title: 'Test Channel',
                  slug: 'test',
                  created: DateTime(2025, 1, 1),
                  playlists: const <String>[],
                ),
              ],
              playlists: const [],
              items: const [],
              channelsRankingScore: const [0.9],
              totalHits: 1,
              processingTimeMs: 10,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['test']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.hasResults, isTrue);

        // Clear state
        bloc.add(MeiliSearchCleared());
        await bloc.stream.first;

        expect(bloc.state.query, isEmpty);
        expect(bloc.state.hasResults, isFalse);
        expect(bloc.state.channels.length, equals(0));
      });
    });

    group('Edge Cases', () {
      test('handles empty query', () async {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult.empty());

        bloc.add(MeiliSearchQueryChanged(const ['']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.query, isEmpty);
        expect(bloc.state.hasResults, isFalse);
      });

      test('handles large result sets', () async {
        final manyChannels = List.generate(
          50,
          (i) => Channel(
            id: 'c$i',
            title: 'Channel $i',
            slug: 'channel-$i',
            created: DateTime(2025, 1, 1).add(Duration(days: i)),
            playlists: const <String>[],
          ),
        );

        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult(
              channels: manyChannels,
              playlists: const [],
              items: const [],
              channelsRankingScore: List.generate(50, (i) => 0.9 - i * 0.01),
              totalHits: 50,
              processingTimeMs: 50,
            ));

        bloc.add(MeiliSearchQueryChanged(const ['popular']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.channels.length, equals(50));
        expect(bloc.state.totalHits, equals(50));
      });

      test('handles query with special characters', () async {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              filters: any(named: 'filters'),
            )).thenAnswer((_) async => MeiliSearchResult.empty());

        bloc.add(MeiliSearchQueryChanged(const ['test!@#\$%^&*()']));
        await bloc.stream.firstWhere((state) => !state.isLoading);

        expect(bloc.state.query, contains('test'));
      });
    });
  });
}
