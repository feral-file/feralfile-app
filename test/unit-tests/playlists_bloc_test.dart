import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockFeralFileFeedManager extends Mock implements FeralFileFeedManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistsBloc playlistsBloc;
  late MockFeralFileFeedManager mockFeedManager;

  // Test data
  final testPlaylists = [
    PlaylistReference(
      playlist: DP1Call(
        dpVersion: '1.0.0',
        id: 'playlist1',
        slug: 'test-playlist-1',
        title: 'Test Playlist 1',
        created: DateTime(2025, 1, 1),
        items: <DP1Item>[],
        signature: '0x123',
      ),
      url: 'https://test.com',
    ),
    PlaylistReference(
      playlist: DP1Call(
        dpVersion: '1.0.0',
        id: 'playlist2',
        slug: 'test-playlist-2',
        title: 'Test Playlist 2',
        created: DateTime(2025, 1, 3),
        items: <DP1Item>[],
        signature: '0x456',
      ),
      url: 'https://test.com',
    ),
  ];

  setUp(() {
    mockFeedManager = MockFeralFileFeedManager();

    // Setup injector
    final getIt = GetIt.instance;
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }
    getIt.registerSingleton<FeralFileFeedManager>(mockFeedManager);

    // Default mock response
    when(() => mockFeedManager.getAllCachedPlaylists())
        .thenAnswer((_) async => testPlaylists);

    playlistsBloc = PlaylistsBloc();
  });

  tearDown(() {
    playlistsBloc.close();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }
  });

  group('PlaylistsBloc - Initial State', () {
    test('should have correct initial state', () {
      expect(playlistsBloc.state, isA<PlaylistsState>());
      expect(playlistsBloc.state.playlists, isEmpty);
      expect(playlistsBloc.state.status, equals(PlaylistsStateStatus.initial));
      expect(playlistsBloc.state.hasMore, isTrue);
      expect(playlistsBloc.state.cursor, isNull);
      expect(playlistsBloc.state.error, isNull);
    });

    test('should have correct state helper getters', () {
      expect(playlistsBloc.state.isInitial, isTrue);
      expect(playlistsBloc.state.isLoading, isFalse);
      expect(playlistsBloc.state.isLoadingMore, isFalse);
      expect(playlistsBloc.state.isLoaded, isFalse);
      expect(playlistsBloc.state.isError, isFalse);
    });
  });

  group('PlaylistsBloc - LoadPlaylistsEvent', () {
    blocTest<PlaylistsBloc, PlaylistsState>(
      'should emit loading and loaded states when playlists are loaded successfully',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenAnswer((_) async => testPlaylists);
        return playlistsBloc;
      },
      act: (bloc) => bloc.add(const LoadPlaylistsEvent()),
      expect: () => [
        const PlaylistsState(
          status: PlaylistsStateStatus.loading,
          playlists: [],
          hasMore: true,
        ),
        PlaylistsState(
          status: PlaylistsStateStatus.loaded,
          playlists: testPlaylists,
          hasMore: false,
          cursor: null,
          error: '',
        ),
      ],
      verify: (_) {
        verify(() => mockFeedManager.getAllCachedPlaylists()).called(1);
      },
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should emit loading and loaded states with empty list when no playlists',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenAnswer((_) async => <PlaylistReference>[]);
        return playlistsBloc;
      },
      act: (bloc) => bloc.add(const LoadPlaylistsEvent()),
      expect: () => <dynamic>[
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loading)
            .having((s) => s.playlists.length, 'playlists length', 0)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loaded)
            .having((s) => s.playlists.length, 'playlists length', 0)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', null)
            .having((s) => s.error, 'error', ''),
      ],
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should emit loading and error states when loading fails',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenThrow(Exception('Failed to load playlists'));
        return playlistsBloc;
      },
      act: (bloc) => bloc.add(const LoadPlaylistsEvent()),
      expect: () => [
        const PlaylistsState(
          status: PlaylistsStateStatus.loading,
          playlists: [],
          hasMore: true,
        ),
        const PlaylistsState(
          status: PlaylistsStateStatus.error,
          playlists: [],
          hasMore: true,
          error: 'Exception: Failed to load playlists',
        ),
      ],
    );
  });

  group('PlaylistsBloc - LoadMorePlaylistsEvent', () {
    blocTest<PlaylistsBloc, PlaylistsState>(
      'should not load more when already loading',
      build: () => playlistsBloc,
      seed: () => const PlaylistsState(
        status: PlaylistsStateStatus.loading,
      ),
      act: (bloc) => bloc.add(const LoadMorePlaylistsEvent()),
      expect: () => <PlaylistsState>[],
      verify: (_) {
        verifyNever(() => mockFeedManager.getAllCachedPlaylists());
      },
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should not load more when already loading more',
      build: () => playlistsBloc,
      seed: () => const PlaylistsState(
        status: PlaylistsStateStatus.loadingMore,
      ),
      act: (bloc) => bloc.add(const LoadMorePlaylistsEvent()),
      expect: () => <PlaylistsState>[],
      verify: (_) {
        verifyNever(() => mockFeedManager.getAllCachedPlaylists());
      },
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should not load more when hasMore is false',
      build: () => playlistsBloc,
      seed: () => const PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        hasMore: false,
      ),
      act: (bloc) => bloc.add(const LoadMorePlaylistsEvent()),
      expect: () => <PlaylistsState>[],
      verify: (_) {
        verifyNever(() => mockFeedManager.getAllCachedPlaylists());
      },
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should emit loadingMore and loaded states when loading more succeeds',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenAnswer((_) async => testPlaylists);
        return playlistsBloc;
      },
      seed: () => PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: <PlaylistReference>[testPlaylists.first],
        hasMore: true,
        cursor: 'cursor-1',
      ),
      act: (bloc) => bloc.add(const LoadMorePlaylistsEvent()),
      expect: () => <dynamic>[
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loadingMore)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.cursor, 'cursor', 'cursor-1'),
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loaded)
            .having((s) => s.playlists.length, 'playlists length', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', null)
            .having((s) => s.error, 'error', ''),
      ],
      verify: (_) {
        verify(() => mockFeedManager.getAllCachedPlaylists()).called(1);
      },
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should emit loadingMore and error states when loading more fails',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenThrow(Exception('Failed to load more'));
        return playlistsBloc;
      },
      seed: () => PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: <PlaylistReference>[testPlaylists.first],
        hasMore: true,
        cursor: 'cursor-1',
      ),
      act: (bloc) => bloc.add(const LoadMorePlaylistsEvent()),
      expect: () => <dynamic>[
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loadingMore)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.cursor, 'cursor', 'cursor-1'),
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.error)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.cursor, 'cursor', 'cursor-1')
            .having((s) => s.error, 'error', 'Exception: Failed to load more'),
      ],
      verify: (_) {
        verify(() => mockFeedManager.getAllCachedPlaylists()).called(1);
      },
    );
  });

  group('PlaylistsBloc - RefreshPlaylistsEvent', () {
    blocTest<PlaylistsBloc, PlaylistsState>(
      'should reset cursor and reload playlists when refreshing',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenAnswer((_) async => testPlaylists);
        return playlistsBloc;
      },
      seed: () => PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: <PlaylistReference>[testPlaylists.first],
        hasMore: false,
        cursor: 'old-cursor',
      ),
      act: (bloc) => bloc.add(const RefreshPlaylistsEvent()),
      expect: () => <dynamic>[
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loading)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', 'old-cursor'),
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loaded)
            .having((s) => s.playlists.length, 'playlists length', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', null)
            .having((s) => s.error, 'error', ''),
      ],
      verify: (_) {
        verify(() => mockFeedManager.getAllCachedPlaylists()).called(1);
      },
    );

    blocTest<PlaylistsBloc, PlaylistsState>(
      'should emit loading and error states when refresh fails',
      build: () {
        when(() => mockFeedManager.getAllCachedPlaylists())
            .thenThrow(Exception('Refresh failed'));
        return playlistsBloc;
      },
      seed: () => PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: <PlaylistReference>[testPlaylists.first],
      ),
      act: (bloc) => bloc.add(const RefreshPlaylistsEvent()),
      expect: () => <dynamic>[
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.loading)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<PlaylistsState>()
            .having((s) => s.status, 'status', PlaylistsStateStatus.error)
            .having((s) => s.playlists.length, 'playlists length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.error, 'error', 'Exception: Refresh failed'),
      ],
    );
  });

  group('PlaylistsState - Equality and CopyWith', () {
    test('should have correct equality comparison', () {
      const state1 = PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: [],
        hasMore: false,
      );
      const state2 = PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: [],
        hasMore: false,
      );
      const state3 = PlaylistsState(
        status: PlaylistsStateStatus.loading,
        playlists: [],
        hasMore: false,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should create state with default values', () {
      const state = PlaylistsState();

      expect(state.playlists, isEmpty);
      expect(state.status, equals(PlaylistsStateStatus.initial));
      expect(state.hasMore, isTrue);
      expect(state.cursor, isNull);
      expect(state.error, isNull);
    });

    test('should create state with custom values', () {
      final state = PlaylistsState(
        status: PlaylistsStateStatus.loading,
        playlists: testPlaylists,
        hasMore: false,
        cursor: 'test-cursor',
        error: 'Test error',
      );

      expect(state.status, equals(PlaylistsStateStatus.loading));
      expect(state.playlists, equals(testPlaylists));
      expect(state.hasMore, isFalse);
      expect(state.cursor, equals('test-cursor'));
      expect(state.error, equals('Test error'));
    });

    test('should copy state with new values', () {
      const originalState = PlaylistsState();
      final newState = originalState.copyWith(
        status: PlaylistsStateStatus.loading,
        hasMore: false,
        cursor: 'new-cursor',
        error: 'New error',
      );

      expect(newState.status, equals(PlaylistsStateStatus.loading));
      expect(newState.hasMore, isFalse);
      expect(newState.cursor, equals('new-cursor'));
      expect(newState.error, equals('New error'));
      expect(newState.playlists, equals(originalState.playlists));
    });

    test('should copy state preserving original values when not specified', () {
      final originalState = PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        playlists: testPlaylists,
        hasMore: false,
        cursor: 'original-cursor',
        error: 'original error',
      );
      final newState = originalState.copyWith(
        status: PlaylistsStateStatus.loading,
      );

      expect(newState.status, equals(PlaylistsStateStatus.loading));
      expect(newState.playlists, equals(testPlaylists));
      expect(newState.hasMore, isFalse);
      expect(newState.cursor, equals('original-cursor'));
      expect(newState.error, equals('original error'));
    });

    test('should have correct hashCode', () {
      const state1 = PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        hasMore: false,
      );
      const state2 = PlaylistsState(
        status: PlaylistsStateStatus.loaded,
        hasMore: false,
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });
  });

  group('PlaylistsState - Status Helpers', () {
    test('isInitial should return true for initial status', () {
      const state = PlaylistsState(status: PlaylistsStateStatus.initial);
      expect(state.isInitial, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isFalse);
    });

    test('isLoading should return true for loading status', () {
      const state = PlaylistsState(status: PlaylistsStateStatus.loading);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isFalse);
    });

    test('isLoadingMore should return true for loadingMore status', () {
      const state = PlaylistsState(status: PlaylistsStateStatus.loadingMore);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isTrue);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isFalse);
    });

    test('isLoaded should return true for loaded status', () {
      const state = PlaylistsState(status: PlaylistsStateStatus.loaded);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isTrue);
      expect(state.isError, isFalse);
    });

    test('isError should return true for error status', () {
      const state = PlaylistsState(status: PlaylistsStateStatus.error);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isTrue);
    });
  });

  group('PlaylistsEvent', () {
    test('LoadPlaylistsEvent should be instantiated', () {
      const event = LoadPlaylistsEvent();
      expect(event, isA<PlaylistsEvent>());
      expect(event, isA<LoadPlaylistsEvent>());
    });

    test('LoadMorePlaylistsEvent should be instantiated', () {
      const event = LoadMorePlaylistsEvent();
      expect(event, isA<PlaylistsEvent>());
      expect(event, isA<LoadMorePlaylistsEvent>());
    });

    test('RefreshPlaylistsEvent should be instantiated', () {
      const event = RefreshPlaylistsEvent();
      expect(event, isA<PlaylistsEvent>());
      expect(event, isA<RefreshPlaylistsEvent>());
    });
  });
}
