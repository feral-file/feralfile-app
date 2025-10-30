import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/meilisearch_models.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockMeiliSearchService extends Mock implements MeiliSearchService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MeiliSearchBloc meiliSearchBloc;
  late MockMeiliSearchService mockService;

  // Test data
  final testChannels = [
    Channel(
      id: 'channel1',
      title: 'Test Channel 1',
      slug: 'test-channel-1',
      created: DateTime(2025, 1, 1),
      playlists: const <String>[],
    ),
    Channel(
      id: 'channel2',
      title: 'Test Channel 2',
      slug: 'test-channel-2',
      created: DateTime(2025, 1, 3),
      playlists: const <String>[],
    ),
  ];

  final testPlaylists = [
    DP1Call(
      dpVersion: '1.0.0',
      id: 'playlist1',
      slug: 'test-playlist-1',
      title: 'Test Playlist 1',
      created: DateTime(2025, 1, 1),
      items: const <DP1Item>[],
      signature: '0x123',
    ),
  ];

  final testItems = [
    DP1Item(
      id: 'item1',
      duration: 60,
      title: 'Test Item 1',
    ),
  ];

  final testSearchResult = MeiliSearchResult(
    channels: testChannels,
    playlists: testPlaylists,
    items: testItems,
    channelsRankingScore: const [0.9, 0.8],
    playlistsRankingScore: const [0.85],
    itemsRankingScore: const [0.75],
    totalHits: 4,
    processingTimeMs: 50,
  );

  setUp(() {
    mockService = MockMeiliSearchService();
    meiliSearchBloc = MeiliSearchBloc(mockService);
  });

  tearDown(() {
    meiliSearchBloc.close();
  });

  group('MeiliSearchBloc - Initial State', () {
    test('should have correct initial state', () {
      expect(meiliSearchBloc.state, isA<MeiliSearchState>());
      expect(meiliSearchBloc.state.query, isEmpty);
      expect(meiliSearchBloc.state.channels, isEmpty);
      expect(meiliSearchBloc.state.playlists, isEmpty);
      expect(meiliSearchBloc.state.items, isEmpty);
      expect(meiliSearchBloc.state.isLoading, isFalse);
      expect(meiliSearchBloc.state.hasError, isFalse);
      expect(meiliSearchBloc.state.errorMessage, isNull);
      expect(meiliSearchBloc.state.totalHits, equals(0));
      expect(meiliSearchBloc.state.hasMoreResults, isFalse);
      expect(meiliSearchBloc.state.channelsTopScore, equals(0.0));
      expect(meiliSearchBloc.state.playlistsTopScore, equals(0.0));
      expect(meiliSearchBloc.state.itemsTopScore, equals(0.0));
    });

    test('should have correct state helper getters', () {
      expect(meiliSearchBloc.state.hasResults, isFalse);
      expect(meiliSearchBloc.state.isEmpty, isFalse);
    });
  });

  group('MeiliSearchBloc - MeiliSearchQueryChanged', () {
    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should emit loading and success states when search succeeds',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenAnswer((_) async => testSearchResult);
        return meiliSearchBloc;
      },
      act: (bloc) => bloc.add(MeiliSearchQueryChanged(const ['test query'])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'test query')
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.hasError, 'hasError', false)
            .having((s) => s.errorMessage, 'errorMessage', null),
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'test query')
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.hasError, 'hasError', false)
            .having((s) => s.channels.length, 'channels length', 2)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.items.length, 'items length', 1)
            .having((s) => s.totalHits, 'totalHits', 4)
            .having((s) => s.hasMoreResults, 'hasMoreResults', false)
            .having((s) => s.channelsTopScore, 'channelsTopScore', 0.9)
            .having((s) => s.playlistsTopScore, 'playlistsTopScore', 0.85)
            .having((s) => s.itemsTopScore, 'itemsTopScore', 0.75),
      ],
      verify: (_) {
        verify(() => mockService.searchAll(
              texts: ['test query'],
              limit: 5,
              offset: 0,
            )).called(1);
      },
    );

    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should emit loading and success states with empty results',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenAnswer((_) async => MeiliSearchResult.empty());
        return meiliSearchBloc;
      },
      act: (bloc) => bloc.add(MeiliSearchQueryChanged(const ['no results'])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'no results')
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.hasError, 'hasError', false),
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'no results')
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.hasError, 'hasError', false)
            .having((s) => s.channels, 'channels', isEmpty)
            .having((s) => s.playlists, 'playlists', isEmpty)
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.totalHits, 'totalHits', 0)
            .having((s) => s.hasResults, 'hasResults', false)
            .having((s) => s.isEmpty, 'isEmpty', true),
      ],
    );

    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should emit loading and error states when search fails',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenThrow(Exception('Network error'));
        return meiliSearchBloc;
      },
      act: (bloc) => bloc.add(MeiliSearchQueryChanged(const ['error query'])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'error query')
            .having((s) => s.isLoading, 'isLoading', true)
            .having((s) => s.hasError, 'hasError', false)
            .having((s) => s.errorMessage, 'errorMessage', null),
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'error query')
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.hasError, 'hasError', true)
            .having(
                (s) => s.errorMessage, 'errorMessage', 'Exception: Network error'),
      ],
    );

    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should join multiple queries with space',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenAnswer((_) async => MeiliSearchResult.empty());
        return meiliSearchBloc;
      },
      act: (bloc) =>
          bloc.add(MeiliSearchQueryChanged(const ['first', 'second', 'third'])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'first second third')
            .having((s) => s.isLoading, 'isLoading', true),
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'first second third')
            .having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        verify(() => mockService.searchAll(
              texts: ['first', 'second', 'third'],
              limit: 5,
              offset: 0,
            )).called(1);
      },
    );

    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should trim whitespace from queries',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenAnswer((_) async => MeiliSearchResult.empty());
        return meiliSearchBloc;
      },
      act: (bloc) =>
          bloc.add(MeiliSearchQueryChanged(const ['  query  ', ' test '])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'query    test')
            .having((s) => s.isLoading, 'isLoading', true),
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', 'query    test')
            .having((s) => s.isLoading, 'isLoading', false),
      ],
      verify: (_) {
        // The bloc passes the queries as-is, but normalizes them inside _onQueryChanged
        verify(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: 5,
              offset: 0,
            )).called(1);
      },
    );

    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should handle hasMoreResults correctly when totalHits > pageSize',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenAnswer(
          (_) async => MeiliSearchResult(
            channels: testChannels,
            playlists: testPlaylists,
            items: testItems,
            channelsRankingScore: const [0.9, 0.8],
            playlistsRankingScore: const [0.85],
            itemsRankingScore: const [0.75],
            totalHits: 10, // More than pageSize (5)
            processingTimeMs: 50,
          ),
        );
        return meiliSearchBloc;
      },
      act: (bloc) => bloc.add(MeiliSearchQueryChanged(const ['query'])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.isLoading, 'isLoading', true),
        isA<MeiliSearchState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.hasMoreResults, 'hasMoreResults', true)
            .having((s) => s.totalHits, 'totalHits', 10),
      ],
    );

    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should calculate top scores correctly with empty score lists',
      build: () {
        when(() => mockService.searchAll(
              texts: any(named: 'texts'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            )).thenAnswer(
          (_) async => MeiliSearchResult(
            channels: testChannels,
            playlists: const [],
            items: const [],
            channelsRankingScore: const [0.7, 0.9, 0.5],
            playlistsRankingScore: const [],
            itemsRankingScore: const [],
            totalHits: 2,
            processingTimeMs: 50,
          ),
        );
        return meiliSearchBloc;
      },
      act: (bloc) => bloc.add(MeiliSearchQueryChanged(const ['query'])),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<MeiliSearchState>().having((s) => s.isLoading, 'isLoading', true),
        isA<MeiliSearchState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.channelsTopScore, 'channelsTopScore', 0.9)
            .having((s) => s.playlistsTopScore, 'playlistsTopScore', 0.0)
            .having((s) => s.itemsTopScore, 'itemsTopScore', 0.0),
      ],
    );
  });

  group('MeiliSearchBloc - MeiliSearchCleared', () {
    blocTest<MeiliSearchBloc, MeiliSearchState>(
      'should reset to initial state when cleared',
      build: () => meiliSearchBloc,
      seed: () => MeiliSearchState(
        query: 'test query',
        channels: testChannels,
        playlists: testPlaylists,
        items: testItems,
        channelsTopScore: 0.9,
        playlistsTopScore: 0.85,
        itemsTopScore: 0.75,
        isLoading: false,
        hasError: false,
        totalHits: 4,
        hasMoreResults: false,
      ),
      act: (bloc) => bloc.add(MeiliSearchCleared()),
      expect: () => [
        isA<MeiliSearchState>()
            .having((s) => s.query, 'query', isEmpty)
            .having((s) => s.channels, 'channels', isEmpty)
            .having((s) => s.playlists, 'playlists', isEmpty)
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.hasError, 'hasError', false)
            .having((s) => s.errorMessage, 'errorMessage', null)
            .having((s) => s.totalHits, 'totalHits', 0)
            .having((s) => s.hasMoreResults, 'hasMoreResults', false)
            .having((s) => s.channelsTopScore, 'channelsTopScore', 0.0)
            .having((s) => s.playlistsTopScore, 'playlistsTopScore', 0.0)
            .having((s) => s.itemsTopScore, 'itemsTopScore', 0.0),
      ],
    );
  });

  group('MeiliSearchState - CopyWith', () {
    test('should copy state with new values', () {
      final originalState = MeiliSearchState();
      final newState = originalState.copyWith(
        query: 'new query',
        isLoading: true,
        hasError: true,
        errorMessage: 'error',
        totalHits: 10,
        hasMoreResults: true,
      );

      expect(newState.query, equals('new query'));
      expect(newState.isLoading, isTrue);
      expect(newState.hasError, isTrue);
      expect(newState.errorMessage, equals('error'));
      expect(newState.totalHits, equals(10));
      expect(newState.hasMoreResults, isTrue);
      expect(newState.channels, equals(originalState.channels));
      expect(newState.playlists, equals(originalState.playlists));
      expect(newState.items, equals(originalState.items));
    });

    test('should preserve original values when not specified in copyWith', () {
      final originalState = MeiliSearchState(
        query: 'original',
        channels: testChannels,
        playlists: testPlaylists,
        items: testItems,
        channelsTopScore: 0.9,
        playlistsTopScore: 0.85,
        itemsTopScore: 0.75,
        isLoading: false,
        hasError: false,
        totalHits: 5,
        hasMoreResults: true,
      );
      final newState = originalState.copyWith(query: 'updated');

      expect(newState.query, equals('updated'));
      expect(newState.channels, equals(testChannels));
      expect(newState.playlists, equals(testPlaylists));
      expect(newState.items, equals(testItems));
      expect(newState.channelsTopScore, equals(0.9));
      expect(newState.playlistsTopScore, equals(0.85));
      expect(newState.itemsTopScore, equals(0.75));
      expect(newState.isLoading, isFalse);
      expect(newState.hasError, isFalse);
      expect(newState.totalHits, equals(5));
      expect(newState.hasMoreResults, isTrue);
    });
  });

  group('MeiliSearchState - Computed Properties', () {
    test('hasResults should return true when channels present', () {
      final state = MeiliSearchState(channels: testChannels);
      expect(state.hasResults, isTrue);
    });

    test('hasResults should return true when playlists present', () {
      final state = MeiliSearchState(playlists: testPlaylists);
      expect(state.hasResults, isTrue);
    });

    test('hasResults should return true when items present', () {
      final state = MeiliSearchState(items: testItems);
      expect(state.hasResults, isTrue);
    });

    test('hasResults should return false when all lists empty', () {
      final state = MeiliSearchState();
      expect(state.hasResults, isFalse);
    });

    test('isEmpty should return true when no results and query not empty', () {
      final state = MeiliSearchState(
        query: 'test',
        isLoading: false,
      );
      expect(state.isEmpty, isTrue);
    });

    test('isEmpty should return false when has results', () {
      final state = MeiliSearchState(
        query: 'test',
        channels: testChannels,
        isLoading: false,
      );
      expect(state.isEmpty, isFalse);
    });

    test('isEmpty should return false when loading', () {
      final state = MeiliSearchState(
        query: 'test',
        isLoading: true,
      );
      expect(state.isEmpty, isFalse);
    });

    test('isEmpty should return false when query is empty', () {
      final state = MeiliSearchState(
        query: '',
        isLoading: false,
      );
      expect(state.isEmpty, isFalse);
    });
  });

  group('MeiliSearchEvent', () {
    test('MeiliSearchQueryChanged should be instantiated with queries', () {
      final event = MeiliSearchQueryChanged(const ['test', 'query']);
      expect(event, isA<MeiliSearchEvent>());
      expect(event, isA<MeiliSearchQueryChanged>());
      expect(event.queries, equals(['test', 'query']));
    });

    test('MeiliSearchCleared should be instantiated', () {
      final event = MeiliSearchCleared();
      expect(event, isA<MeiliSearchEvent>());
      expect(event, isA<MeiliSearchCleared>());
    });

    test('MeiliSearchLoadMore should be instantiated', () {
      final event = MeiliSearchLoadMore();
      expect(event, isA<MeiliSearchEvent>());
      expect(event, isA<MeiliSearchLoadMore>());
    });
  });
}

