import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_playlist_data.dart';
import 'mocks/dp1_feed_mocks.dart';

void main() {
  late BaseDP1FeedServiceImpl service;
  late MockDP1FeedApi mockApi;
  late MockBaseFeedCache mockCache;
  late DP1Call testPlaylist;

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(MockBaseFeedCache());
    registerFallbackValue(MockDP1FeedApi());
    registerFallbackValue(Future.value(<String, dynamic>{}));
    registerFallbackValue(DP1Call(
      id: 'fallback',
      slug: 'fallback',
      title: 'Fallback',
      dpVersion: '1.0.0',
      created: DateTime(2024, 1, 1),
      items: [],
      signature: 'fallback',
    ));
    registerFallbackValue(DP1PlaylistResponse([], false, null));
    registerFallbackValue(DP1PlaylistItemsResponse([], false, null));
  });

  setUp(() {
    mockApi = MockDP1FeedApi();
    mockCache = MockBaseFeedCache();
    service = BaseDP1FeedServiceImpl(
      baseUrl: 'https://test.feed.com',
      isExternalFeedService: false,
    );

    // Initialize service with mocks
    service.api = mockApi;
    service.cache = mockCache;

    testPlaylist = MockPlaylistData.create();
  });

  tearDown(() {
    resetMocktailState();
  });

  group('BaseDP1FeedServiceImpl - Initialization', () {
    test('should initialize with correct baseUrl', () {
      final testService = BaseDP1FeedServiceImpl(
        baseUrl: 'https://test.feed.com',
        isExternalFeedService: false,
      );
      expect(testService.baseUrl, 'https://test.feed.com');
      expect(testService.isExternalFeedService, false);
    });

    test('should initialize with isExternalFeedService = true', () {
      final testService = BaseDP1FeedServiceImpl(
        baseUrl: 'https://external.feed.com',
        isExternalFeedService: true,
      );
      expect(testService.isExternalFeedService, true);
    });

    test('should have init method defined', () {
      // Arrange
      final testService = BaseDP1FeedServiceImpl(
        baseUrl: 'https://test.feed.com',
        isExternalFeedService: false,
      );

      // Assert - verify init method exists
      expect(testService.init, isA<Function>());
    });

    test('should initialize service correctly', () {
      // Arrange & Act
      final testService = BaseDP1FeedServiceImpl(
        baseUrl: 'https://test.feed.com',
        isExternalFeedService: false,
      );

      // Assert - verify service properties
      expect(testService.baseUrl, 'https://test.feed.com');
      expect(testService.isExternalFeedService, false);
      expect(testService.init, isA<Function>());
    });

    test('should handle init method for manual initialization', () {
      // Arrange
      final testService = BaseDP1FeedServiceImpl(
        baseUrl: 'https://custom.feed.com',
        isExternalFeedService: true,
      );

      // Assert - verify init method exists and service is configured
      expect(testService.baseUrl, 'https://custom.feed.com');
      expect(testService.isExternalFeedService, true);
      // Note: init() is not tested here as it requires Hive initialization
      // which should be tested in integration tests
    });
  });

  group('BaseDP1FeedServiceImpl - Create Playlist', () {
    test('should create playlist successfully', () async {
      // Arrange
      final request = DP1CreatePlaylistRequest(
        dpVersion: '1.0.0',
        title: 'Test Playlist',
        items: [],
      );
      when(() => mockApi.createPlaylist(any()))
          .thenAnswer((_) async => testPlaylist);

      // Act
      final result = await service.createPlaylist(request: request);

      // Assert
      expect(result, isNotNull);
      expect(result.id, testPlaylist.id);
      expect(result.title, testPlaylist.title);
      verify(() => mockApi.createPlaylist(any())).called(1);
    });

    test('should create playlist without cloud sync', () async {
      // Arrange
      final request = DP1CreatePlaylistRequest(
        dpVersion: '1.0.0',
        title: 'Test Playlist',
        items: [],
      );
      when(() => mockApi.createPlaylist(any()))
          .thenAnswer((_) async => testPlaylist);

      // Act
      final result =
          await service.createPlaylist(request: request, isSyncToCloud: false);

      // Assert
      expect(result, isNotNull);
      verify(() => mockApi.createPlaylist(any())).called(1);
    });
  });

  group('BaseDP1FeedServiceImpl - Update Playlist', () {
    test('should update playlist successfully', () async {
      // Arrange
      const playlistId = 'playlist_123';
      final request = DP1CreatePlaylistRequest(
        dpVersion: '1.0.0',
        title: 'Updated Playlist',
        items: [],
      );
      when(() => mockApi.updatePlaylist(any(), any()))
          .thenAnswer((_) async => testPlaylist);

      // Act
      final result = await service.updatePlaylist(
        playlistId: playlistId,
        request: request,
      );

      // Assert
      expect(result, isNotNull);
      verify(() => mockApi.updatePlaylist(any(), any())).called(1);
    });
  });

  group('BaseDP1FeedServiceImpl - Get Playlist By ID', () {
    test('should return cached playlist when using cache', () async {
      // Arrange
      const playlistId = 'playlist_123';
      when(() => mockCache.getPlaylistById(playlistId))
          .thenReturn(testPlaylist);

      // Act
      final result =
          await service.getPlaylistById(playlistId, usingCache: true);

      // Assert
      expect(result, isNotNull);
      expect(result, testPlaylist);
      verify(() => mockCache.getPlaylistById(playlistId)).called(1);
      verifyNever(() => mockApi.getPlaylistById(any()));
    });

    test('should fetch from API when not using cache', () async {
      // Arrange
      const playlistId = 'playlist_123';
      when(() => mockCache.getPlaylistById(playlistId)).thenReturn(null);
      when(() => mockApi.getPlaylistById(any()))
          .thenAnswer((_) async => testPlaylist);

      // Act
      final result =
          await service.getPlaylistById(playlistId, usingCache: false);

      // Assert
      expect(result, isNotNull);
      expect(result, testPlaylist);
      verify(() => mockApi.getPlaylistById(any())).called(1);
    });

    test('should return null when API throws error', () async {
      // Arrange
      const playlistId = 'playlist_123';
      when(() => mockCache.getPlaylistById(playlistId)).thenReturn(null);
      when(() => mockApi.getPlaylistById(any())).thenThrow(Exception('Error'));

      // Act
      final result =
          await service.getPlaylistById(playlistId, usingCache: false);

      // Assert
      expect(result, isNull);
    });
  });

  group('BaseDP1FeedServiceImpl - Get Playlists', () {
    test('should get playlists with cursor and limit', () async {
      // Arrange
      const cursor = 'cursor_123';
      const limit = 50;
      final mockResponse = DP1FeedMockData.createPlaylistResponse(
        items: [testPlaylist],
        hasMore: false,
        cursor: null,
      );
      when(() => mockApi.getAllPlaylists(cursor: cursor, limit: limit))
          .thenAnswer((_) async => mockResponse);
      when(() => mockCache.insertListPlaylists(any())).thenReturn(null);

      // Act
      final result = await service.getPlaylists(cursor: cursor, limit: limit);

      // Assert
      expect(result, isNotNull);
      expect(result.items, hasLength(1));
      expect(result.hasMore, false);
      verify(() => mockApi.getAllPlaylists(cursor: cursor, limit: limit))
          .called(1);
      verify(() => mockCache.insertListPlaylists(any())).called(1);
    });

    test('should get all playlists without pagination', () async {
      // Arrange
      final mockResponse1 = DP1FeedMockData.createPlaylistResponse(
        items: List.generate(
            50, (i) => MockPlaylistData.create(id: 'playlist_$i')),
        hasMore: true,
        cursor: 'cursor_50',
      );
      final mockResponse2 = DP1FeedMockData.createPlaylistResponse(
        items: List.generate(
            30, (i) => MockPlaylistData.create(id: 'playlist_${i + 50}')),
        hasMore: false,
        cursor: null,
      );

      when(() => mockApi.getAllPlaylists(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((invocation) async {
        final cursorParam = invocation.namedArguments[#cursor] as String?;
        if (cursorParam == null) {
          return mockResponse1;
        }
        return mockResponse2;
      });

      // Act
      final result = await service.getAllPlaylists();

      // Assert
      expect(result, isNotNull);
      expect(result, hasLength(80));
      verify(() => mockApi.getAllPlaylists(
          cursor: any(named: 'cursor'), limit: any(named: 'limit'))).called(2);
    });
  });

  group('BaseDP1FeedServiceImpl - Get Cached Playlists', () {
    test('should return all cached playlists', () {
      // Arrange
      final cachedPlaylists = MockPlaylistData.createList(count: 5);
      when(() => mockCache.getAllPlaylists()).thenReturn(cachedPlaylists);

      // Act
      final result = service.getAllCachedPlaylists();

      // Assert
      expect(result, hasLength(5));
      expect(result, cachedPlaylists);
      verify(() => mockCache.getAllPlaylists()).called(1);
    });

    test('should return empty list when cache is empty', () {
      // Arrange
      when(() => mockCache.getAllPlaylists()).thenReturn([]);

      // Act
      final result = service.getAllCachedPlaylists();

      // Assert
      expect(result, isEmpty);
    });
  });

  group('BaseDP1FeedServiceImpl - Delete Playlist', () {
    test('should delete playlist and remove from cache', () async {
      // Arrange
      const playlistId = 'playlist_123';
      when(() => mockApi.deletePlaylist(playlistId))
          .thenAnswer((_) async => null);
      when(() => mockCache.removePlaylistById(playlistId)).thenReturn(null);

      // Act
      final result = await service.deletePlaylist(playlistId);

      // Assert
      expect(result, isTrue);
      verify(() => mockApi.deletePlaylist(playlistId)).called(1);
      verify(() => mockCache.removePlaylistById(playlistId)).called(1);
    });
  });

  group('BaseDP1FeedServiceImpl - Get Playlist Items', () {
    test('should get playlist items with cursor and limit', () async {
      // Arrange
      const cursor = 'cursor_123';
      const limit = 50;
      final mockResponse = DP1FeedMockData.createPlaylistItemsResponse(
        hasMore: false,
        cursor: null,
        itemCount: 10,
      );
      when(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .thenAnswer((_) async => mockResponse);

      // Act
      final result =
          await service.getPlaylistItems(cursor: cursor, limit: limit);

      // Assert
      expect(result, isNotNull);
      expect(result.items, hasLength(10));
      expect(result.hasMore, false);
      verify(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .called(1);
    });

    test('should get playlist items with specific item data', () async {
      // Arrange
      const cursor = 'cursor_123';
      const limit = 50;
      final mockResponse =
          DP1FeedMockData.createPlaylistItemsResponseWithProvenance();
      when(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .thenAnswer((_) async => mockResponse);

      // Act
      final result =
          await service.getPlaylistItems(cursor: cursor, limit: limit);

      // Assert
      expect(result, isNotNull);
      expect(result.items, isNotEmpty);
      expect(result.items.first.provenance, isNotNull);
      verify(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .called(1);
    });

    test('should get playlist items with different durations', () async {
      // Arrange
      const String? cursor = null;
      const limit = 100;
      final mockResponse =
          DP1FeedMockData.createPlaylistItemsResponseWithDifferentDurations();
      when(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .thenAnswer((_) async => mockResponse);

      // Act
      final result =
          await service.getPlaylistItems(cursor: cursor, limit: limit);

      // Assert
      expect(result, isNotNull);
      expect(result.items, hasLength(4));
      expect(result.items.map((item) => item.duration).toList(),
          [30, 60, 120, 300]);
      verify(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .called(1);
    });

    test('should get empty playlist items', () async {
      // Arrange
      const cursor = 'cursor_end';
      const limit = 50;
      final mockResponse = DP1FeedMockData.createEmptyPlaylistItemsResponse();
      when(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .thenAnswer((_) async => mockResponse);

      // Act
      final result =
          await service.getPlaylistItems(cursor: cursor, limit: limit);

      // Assert
      expect(result, isNotNull);
      expect(result.items, isEmpty);
      expect(result.hasMore, false);
      verify(() => mockApi.getPlaylistItems(cursor: cursor, limit: limit))
          .called(1);
    });
  });

  group('BaseDP1FeedServiceImpl - Cache Management', () {
    test('should clear cache', () {
      // Arrange
      when(() => mockCache.clearAll()).thenReturn(null);

      // Act
      service.clearCache();

      // Assert
      verify(() => mockCache.clearAll()).called(1);
    });

    test('should reload cache successfully', () async {
      // Arrange
      final mockResponse = DP1FeedMockData.createPlaylistResponse(
        items: [testPlaylist],
        hasMore: false,
        cursor: null,
      );
      when(() => mockCache.clearAll()).thenReturn(null);
      when(() => mockApi.getAllPlaylists(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => mockResponse);
      when(() => mockCache.insertListPlaylists(any())).thenReturn(null);

      // Act
      await service.reloadCache();

      // Assert
      verify(() => mockCache.clearAll()).called(1);
      verify(() => mockApi.getAllPlaylists(
          cursor: any(named: 'cursor'), limit: any(named: 'limit'))).called(1);
      verify(() => mockCache.insertListPlaylists(any())).called(1);
    });

    test('should not reload cache when already reloading', () async {
      // Arrange
      when(() => mockCache.clearAll()).thenReturn(null);
      when(() => mockCache.insertListPlaylists(any())).thenReturn(null);
      when(() => mockApi.getAllPlaylists(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => Future.delayed(
            const Duration(milliseconds: 100),
            () => DP1FeedMockData.createPlaylistResponse(),
          ));

      // Act
      // Start two reload operations concurrently
      final future1 = service.reloadCache();
      final future2 = service.reloadCache();

      await Future.wait([future1, future2]);

      // Assert
      // clearAll should only be called once because the second call should be ignored
      verify(() => mockCache.clearAll()).called(1);
    });
  });
}
