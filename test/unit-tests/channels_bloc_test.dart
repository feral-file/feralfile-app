import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockFeralFileFeedManager extends Mock implements FeralFileFeedManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChannelsBloc channelsBloc;
  late MockFeralFileFeedManager mockFeedManager;

  // Test data
  final testChannels = [
    ChannelReference(
      channel: Channel(
        id: 'channel1',
        title: 'Test Channel 1',
        slug: 'test-channel-1',
        created: DateTime(2025, 1, 1),
        playlists: <String>[],
      ),
      url: 'https://test.com',
    ),
    ChannelReference(
      channel: Channel(
        id: 'channel2',
        title: 'Test Channel 2',
        slug: 'test-channel-2',
        created: DateTime(2025, 1, 3),
        playlists: <String>[],
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
    when(() => mockFeedManager.getAllCachedChannels())
        .thenAnswer((_) async => testChannels);

    channelsBloc = ChannelsBloc();
  });

  tearDown(() {
    channelsBloc.close();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<FeralFileFeedManager>()) {
      getIt.unregister<FeralFileFeedManager>();
    }
  });

  group('ChannelsBloc - Initial State', () {
    test('should have correct initial state', () {
      expect(channelsBloc.state, isA<ChannelsState>());
      expect(channelsBloc.state.channelReferences, isEmpty);
      expect(channelsBloc.state.status, equals(ChannelsStateStatus.initial));
      expect(channelsBloc.state.hasMore, isTrue);
      expect(channelsBloc.state.cursor, isNull);
      expect(channelsBloc.state.error, isNull);
    });

    test('should have correct state helper getters', () {
      expect(channelsBloc.state.isInitial, isTrue);
      expect(channelsBloc.state.isLoading, isFalse);
      expect(channelsBloc.state.isLoadingMore, isFalse);
      expect(channelsBloc.state.isLoaded, isFalse);
      expect(channelsBloc.state.isError, isFalse);
    });
  });

  group('ChannelsBloc - LoadChannelsEvent', () {
    blocTest<ChannelsBloc, ChannelsState>(
      'should emit loading and loaded states when channels are loaded successfully',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenAnswer((_) async => testChannels);
        return channelsBloc;
      },
      act: (bloc) => bloc.add(const LoadChannelsEvent()),
      expect: () => [
        const ChannelsState(
          status: ChannelsStateStatus.loading,
          channelReferences: [],
          hasMore: true,
        ),
        ChannelsState(
          status: ChannelsStateStatus.loaded,
          channelReferences: testChannels,
          hasMore: false,
          cursor: null,
          error: '',
        ),
      ],
      verify: (_) {
        verify(() => mockFeedManager.getAllCachedChannels()).called(1);
      },
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should emit loading and loaded states with empty list when no channels',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenAnswer((_) async => <ChannelReference>[]);
        return channelsBloc;
      },
      act: (bloc) => bloc.add(const LoadChannelsEvent()),
      expect: () => <dynamic>[
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loading)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 0)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loaded)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 0)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', null)
            .having((s) => s.error, 'error', ''),
      ],
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should emit loading and error states when loading fails',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenThrow(Exception('Failed to load channels'));
        return channelsBloc;
      },
      act: (bloc) => bloc.add(const LoadChannelsEvent()),
      expect: () => [
        const ChannelsState(
          status: ChannelsStateStatus.loading,
          channelReferences: [],
          hasMore: true,
        ),
        const ChannelsState(
          status: ChannelsStateStatus.error,
          channelReferences: const [],
          hasMore: true,
          error: 'Exception: Failed to load channels',
        ),
      ],
    );
  });

  group('ChannelsBloc - LoadMoreChannelsEvent', () {
    blocTest<ChannelsBloc, ChannelsState>(
      'should not load more when already loading',
      build: () => channelsBloc,
      seed: () => const ChannelsState(
        status: ChannelsStateStatus.loading,
      ),
      act: (bloc) => bloc.add(const LoadMoreChannelsEvent()),
      expect: () => <ChannelsState>[],
      verify: (_) {
        verifyNever(() => mockFeedManager.getAllCachedChannels());
      },
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should not load more when already loading more',
      build: () => channelsBloc,
      seed: () => const ChannelsState(
        status: ChannelsStateStatus.loadingMore,
      ),
      act: (bloc) => bloc.add(const LoadMoreChannelsEvent()),
      expect: () => <ChannelsState>[],
      verify: (_) {
        verifyNever(() => mockFeedManager.getAllCachedChannels());
      },
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should not load more when hasMore is false',
      build: () => channelsBloc,
      seed: () => const ChannelsState(
        status: ChannelsStateStatus.loaded,
        hasMore: false,
      ),
      act: (bloc) => bloc.add(const LoadMoreChannelsEvent()),
      expect: () => <ChannelsState>[],
      verify: (_) {
        verifyNever(() => mockFeedManager.getAllCachedChannels());
      },
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should emit loadingMore and loaded states when loading more succeeds',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenAnswer((_) async => testChannels);
        return channelsBloc;
      },
      seed: () => ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: <ChannelReference>[testChannels.first],
        hasMore: true,
        cursor: 'cursor-1',
      ),
      act: (bloc) => bloc.add(const LoadMoreChannelsEvent()),
      expect: () => <dynamic>[
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loadingMore)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.cursor, 'cursor', 'cursor-1'),
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loaded)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', null)
            .having((s) => s.error, 'error', ''),
      ],
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should emit loadingMore and error states when loading more fails',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenThrow(Exception('Failed to load more'));
        return channelsBloc;
      },
      seed: () => ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: <ChannelReference>[testChannels.first],
        hasMore: true,
        cursor: 'cursor-1',
      ),
      act: (bloc) => bloc.add(const LoadMoreChannelsEvent()),
      expect: () => <dynamic>[
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loadingMore)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.cursor, 'cursor', 'cursor-1'),
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.error)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.cursor, 'cursor', 'cursor-1')
            .having((s) => s.error, 'error', 'Exception: Failed to load more'),
      ],
    );
  });

  group('ChannelsBloc - RefreshChannelsEvent', () {
    blocTest<ChannelsBloc, ChannelsState>(
      'should reset cursor and reload channels when refreshing',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenAnswer((_) async => testChannels);
        return channelsBloc;
      },
      seed: () => ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: <ChannelReference>[testChannels.first],
        hasMore: false,
        cursor: 'old-cursor',
      ),
      act: (bloc) => bloc.add(const RefreshChannelsEvent()),
      expect: () => <dynamic>[
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loading)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 1)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', 'old-cursor'),
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loaded)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 2)
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.cursor, 'cursor', null)
            .having((s) => s.error, 'error', ''),
      ],
      verify: (_) {
        verify(() => mockFeedManager.getAllCachedChannels()).called(1);
      },
    );

    blocTest<ChannelsBloc, ChannelsState>(
      'should emit loading and error states when refresh fails',
      build: () {
        when(() => mockFeedManager.getAllCachedChannels())
            .thenThrow(Exception('Refresh failed'));
        return channelsBloc;
      },
      seed: () => ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: <ChannelReference>[testChannels.first],
      ),
      act: (bloc) => bloc.add(const RefreshChannelsEvent()),
      expect: () => <dynamic>[
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.loading)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 1)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<ChannelsState>()
            .having((s) => s.status, 'status', ChannelsStateStatus.error)
            .having((s) => s.channelReferences.length,
                'channelReferences length', 1)
            .having((s) => s.hasMore, 'hasMore', true)
            .having((s) => s.error, 'error', 'Exception: Refresh failed'),
      ],
    );
  });

  group('ChannelsState - Equality and CopyWith', () {
    test('should have correct equality comparison', () {
      const state1 = ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: [],
        hasMore: false,
      );
      const state2 = ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: [],
        hasMore: false,
      );
      const state3 = ChannelsState(
        status: ChannelsStateStatus.loading,
        channelReferences: [],
        hasMore: false,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should create state with default values', () {
      const state = ChannelsState();

      expect(state.channelReferences, isEmpty);
      expect(state.status, equals(ChannelsStateStatus.initial));
      expect(state.hasMore, isTrue);
      expect(state.cursor, isNull);
      expect(state.error, isNull);
    });

    test('should create state with custom values', () {
      final state = ChannelsState(
        status: ChannelsStateStatus.loading,
        channelReferences: testChannels,
        hasMore: false,
        cursor: 'test-cursor',
        error: 'Test error',
      );

      expect(state.status, equals(ChannelsStateStatus.loading));
      expect(state.channelReferences, equals(testChannels));
      expect(state.hasMore, isFalse);
      expect(state.cursor, equals('test-cursor'));
      expect(state.error, equals('Test error'));
    });

    test('should copy state with new values', () {
      const originalState = ChannelsState();
      final newState = originalState.copyWith(
        status: ChannelsStateStatus.loading,
        hasMore: false,
        cursor: 'new-cursor',
        error: 'New error',
      );

      expect(newState.status, equals(ChannelsStateStatus.loading));
      expect(newState.hasMore, isFalse);
      expect(newState.cursor, equals('new-cursor'));
      expect(newState.error, equals('New error'));
      expect(
          newState.channelReferences, equals(originalState.channelReferences));
    });

    test('should copy state preserving original values when not specified', () {
      final originalState = ChannelsState(
        status: ChannelsStateStatus.loaded,
        channelReferences: testChannels,
        hasMore: false,
        cursor: 'original-cursor',
        error: 'original error',
      );
      final newState = originalState.copyWith(
        status: ChannelsStateStatus.loading,
      );

      expect(newState.status, equals(ChannelsStateStatus.loading));
      expect(newState.channelReferences, equals(testChannels));
      expect(newState.hasMore, isFalse);
      expect(newState.cursor, equals('original-cursor'));
      expect(newState.error, equals('original error'));
    });

    test('should have correct hashCode', () {
      const state1 = ChannelsState(
        status: ChannelsStateStatus.loaded,
        hasMore: false,
      );
      const state2 = ChannelsState(
        status: ChannelsStateStatus.loaded,
        hasMore: false,
      );

      expect(state1.hashCode, equals(state2.hashCode));
    });
  });

  group('ChannelsState - Status Helpers', () {
    test('isInitial should return true for initial status', () {
      const state = ChannelsState(status: ChannelsStateStatus.initial);
      expect(state.isInitial, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isFalse);
    });

    test('isLoading should return true for loading status', () {
      const state = ChannelsState(status: ChannelsStateStatus.loading);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isTrue);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isFalse);
    });

    test('isLoadingMore should return true for loadingMore status', () {
      const state = ChannelsState(status: ChannelsStateStatus.loadingMore);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isTrue);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isFalse);
    });

    test('isLoaded should return true for loaded status', () {
      const state = ChannelsState(status: ChannelsStateStatus.loaded);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isTrue);
      expect(state.isError, isFalse);
    });

    test('isError should return true for error status', () {
      const state = ChannelsState(status: ChannelsStateStatus.error);
      expect(state.isInitial, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.isLoaded, isFalse);
      expect(state.isError, isTrue);
    });
  });

  group('ChannelsEvent', () {
    test('LoadChannelsEvent should be instantiated', () {
      const event = LoadChannelsEvent();
      expect(event, isA<ChannelsEvent>());
      expect(event, isA<LoadChannelsEvent>());
    });

    test('LoadMoreChannelsEvent should be instantiated', () {
      const event = LoadMoreChannelsEvent();
      expect(event, isA<ChannelsEvent>());
      expect(event, isA<LoadMoreChannelsEvent>());
    });

    test('RefreshChannelsEvent should be instantiated', () {
      const event = RefreshChannelsEvent();
      expect(event, isA<ChannelsEvent>());
      expect(event, isA<RefreshChannelsEvent>());
    });
  });
}
