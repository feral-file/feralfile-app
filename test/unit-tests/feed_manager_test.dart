import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_channel_data.dart';
import '../mock_data/mock_dp1_item_data.dart';

void main() {
  late FeralFileFeedManager feralFileFeedManager;
  late MockFeralFileDP1FeedService mockService1;
  late MockFeralFileDP1FeedService mockService2;

  setUp(() {
    feralFileFeedManager = FeralFileFeedManager();
    mockService1 = MockFeralFileDP1FeedService();
    mockService2 = MockFeralFileDP1FeedService();
  });

  tearDown(() {
    // Clear feed services
    feralFileFeedManager
      ..removeFeedServiceByUrl('https://api1.example.com')
      ..removeFeedServiceByUrl('https://api2.example.com');
  });

  group('FeedManager - Basic Operations', () {
    test('should add feed service', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);

      // Act
      final result = feralFileFeedManager.addFeedService(mockService1);

      // Assert
      expect(result, equals(mockService1));
      expect(
        feralFileFeedManager.isFeedServiceExists('https://api1.example.com'),
        isTrue,
      );
    });

    test('should not add duplicate feed service', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);

      // Act
      feralFileFeedManager.addFeedService(mockService1);
      final result = feralFileFeedManager.addFeedService(mockService1);

      // Assert
      expect(result, equals(mockService1));
      expect(feralFileFeedManager.feedServices.length, equals(1));
    });

    test('should get feed service by URL', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      feralFileFeedManager.addFeedService(mockService1);

      // Act
      final result =
          feralFileFeedManager.getFeedServiceByUrl('https://api1.example.com');

      // Assert
      expect(result, equals(mockService1));
    });

    test('should return null for non-existent feed service', () {
      // Act
      final result =
          feralFileFeedManager.getFeedServiceByUrl('https://nonexistent.com');

      // Assert
      expect(result, isNull);
    });

    test('should remove feed service by URL', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      when(() => mockService2.baseUrl).thenReturn('https://api2.example.com');
      when(() => mockService2.clearCache()).thenReturn(null);

      feralFileFeedManager
        ..addFeedService(mockService1)
        ..addFeedService(mockService2)

        // Act
        ..removeFeedServiceByUrl('https://api1.example.com');

      // Assert
      expect(
        feralFileFeedManager.isFeedServiceExists('https://api1.example.com'),
        isFalse,
      );
      expect(
        feralFileFeedManager.isFeedServiceExists('https://api2.example.com'),
        isTrue,
      );
    });

    test('should check if feed service exists', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      feralFileFeedManager.addFeedService(mockService1);

      // Act & Assert
      expect(
        feralFileFeedManager.isFeedServiceExists('https://api1.example.com'),
        isTrue,
      );
      expect(
        feralFileFeedManager.isFeedServiceExists('https://nonexistent.com'),
        isFalse,
      );
    });

    test('should get all feed services', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      when(() => mockService2.baseUrl).thenReturn('https://api2.example.com');
      when(() => mockService2.clearCache()).thenReturn(null);

      feralFileFeedManager
        ..addFeedService(mockService1)
        ..addFeedService(mockService2);

      // Act
      final services = feralFileFeedManager.feedServices;

      // Assert
      expect(services.length, equals(2));
    });

    test('should clear all cache', () {
      // Arrange
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      when(() => mockService2.baseUrl).thenReturn('https://api2.example.com');
      when(() => mockService2.clearCache()).thenReturn(null);

      feralFileFeedManager
        ..addFeedService(mockService1)
        ..addFeedService(mockService2)

        // Act
        ..clearAllCache();

      // Assert
      verify(() => mockService1.clearCache()).called(1);
      verify(() => mockService2.clearCache()).called(1);
    });
  });

  group('FeralFileFeedManager - Remote Config', () {
    test('should initialize successfully', () async {
      // Act
      await feralFileFeedManager.init();

      // Assert - Should not throw
      expect(feralFileFeedManager, isNotNull);
    });

    test('should get all cached channels', () async {
      // Arrange
      final channels = MockChannelData.createList(count: 3);
      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      when(() => mockService1.getAllCachedChannels()).thenReturn(channels);

      feralFileFeedManager.addFeedService(mockService1);

      // Act
      final result = await feralFileFeedManager.getAllCachedChannels();

      // Assert
      expect(result.length, equals(3));
      verify(() => mockService1.getAllCachedChannels()).called(1);
    });

    test('should get playlist items by list of channels', () async {
      // Arrange
      final channel = RemoteConfigChannel(
        endpoint: 'https://api1.example.com',
        channelId: 'channel_123',
      );
      final items = MockDP1ItemData.createList(count: 3);

      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      when(
        () => mockService1.getPlaylistItemsOfChannel(
          channelId: 'channel_123',
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          usingCache: any(named: 'usingCache'),
        ),
      ).thenAnswer(
        (_) async => DP1PlaylistItemsResponse(items, false, null),
      );

      feralFileFeedManager.addFeedService(mockService1);

      // Act
      final result =
          await feralFileFeedManager.getPlaylistItemsByListOfChannels(
        channels: [channel],
      );

      // Assert
      expect(result.items.length, equals(3));
    });

    test('should handle empty channels list', () async {
      // Act
      final result = await feralFileFeedManager
          .getPlaylistItemsByListOfChannels(channels: []);

      // Assert
      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.cursor, isNull);
    });

    test('should handle hasMore = true with cursor', () async {
      // Arrange
      final channel = RemoteConfigChannel(
        endpoint: 'https://api1.example.com',
        channelId: 'channel_123',
      );
      final items = MockDP1ItemData.createList(count: 2);

      when(() => mockService1.baseUrl).thenReturn('https://api1.example.com');
      when(() => mockService1.clearCache()).thenReturn(null);
      when(
        () => mockService1.getPlaylistItemsOfChannel(
          channelId: 'channel_123',
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          usingCache: any(named: 'usingCache'),
        ),
      ).thenAnswer(
        (_) async => DP1PlaylistItemsResponse(items, true, 'next_cursor'),
      );

      feralFileFeedManager.addFeedService(mockService1);

      // Act
      final result =
          await feralFileFeedManager.getPlaylistItemsByListOfChannels(
        channels: [channel],
      );

      // Assert
      expect(result.items.length, equals(2));
      expect(result.hasMore, isTrue);
      expect(result.cursor, equals('0:next_cursor'));
    });
  });
}

// Mock classes
class MockFeralFileDP1FeedService extends Mock
    implements FeralFileDP1FeedService {}
