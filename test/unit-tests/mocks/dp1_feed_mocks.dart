import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/feed_cache.dart';
import 'package:mocktail/mocktail.dart';

import '../mock_data/mock_dp1_item_data.dart';

/// Mock for DP1FeedApi using mocktail
class MockDP1FeedApi extends Mock implements DP1FeedApi {}

/// Mock for BaseFeedCache using mocktail
class MockBaseFeedCache extends Mock implements BaseFeedCache {}

/// Helper class to create mock data
class DP1FeedMockData {
  /// Create a mock DP1Call (playlist)
  static DP1Call createPlaylist({
    String id = 'test_playlist_1',
    String title = 'Test Playlist',
    String slug = 'test-playlist',
    DateTime? created,
  }) {
    return DP1Call(
      id: id,
      slug: slug,
      title: title,
      dpVersion: '1.0.0',
      created: created ?? DateTime(2024, 1, 1),
      items: [],
      signature: 'test-signature',
    );
  }

  /// Create a mock DP1PlaylistResponse
  static DP1PlaylistResponse createPlaylistResponse({
    List<DP1Call> items = const [],
    bool hasMore = false,
    String? cursor,
  }) {
    return DP1PlaylistResponse(
      items.isNotEmpty ? items : [createPlaylist()],
      hasMore,
      cursor,
    );
  }

  /// Create a mock DP1PlaylistItemsResponse
  static DP1PlaylistItemsResponse createPlaylistItemsResponse({
    List<DP1Item>? items,
    bool hasMore = false,
    String? cursor,
    int itemCount = 5,
  }) {
    // Use MockDP1ItemData if items not provided
    final itemsToUse = items ?? MockDP1ItemData.createList(count: itemCount);
    return DP1PlaylistItemsResponse(itemsToUse, hasMore, cursor);
  }

  /// Create a mock DP1PlaylistItemsResponse with specific items
  static DP1PlaylistItemsResponse createPlaylistItemsResponseWithItems(
    List<DP1Item> items, {
    bool hasMore = false,
    String? cursor,
  }) {
    return DP1PlaylistItemsResponse(items, hasMore, cursor);
  }

  /// Create a mock DP1PlaylistItemsResponse with provenance items
  static DP1PlaylistItemsResponse createPlaylistItemsResponseWithProvenance({
    bool hasMore = false,
    String? cursor,
  }) {
    final items = MockDP1ItemData.createWithDifferentProvenance();
    return DP1PlaylistItemsResponse(items, hasMore, cursor);
  }

  /// Create a mock DP1PlaylistItemsResponse with items of different durations
  static DP1PlaylistItemsResponse
      createPlaylistItemsResponseWithDifferentDurations({
    bool hasMore = false,
    String? cursor,
  }) {
    final items = MockDP1ItemData.createWithDifferentDurations();
    return DP1PlaylistItemsResponse(items, hasMore, cursor);
  }

  /// Create a mock DP1PlaylistItemsResponse with different licenses
  static DP1PlaylistItemsResponse
      createPlaylistItemsResponseWithDifferentLicenses({
    bool hasMore = false,
    String? cursor,
  }) {
    final items = MockDP1ItemData.createWithDifferentLicenses();
    return DP1PlaylistItemsResponse(items, hasMore, cursor);
  }

  /// Create an empty mock DP1PlaylistItemsResponse
  static DP1PlaylistItemsResponse createEmptyPlaylistItemsResponse({
    String? cursor,
  }) {
    return DP1PlaylistItemsResponse([], false, cursor);
  }
}
