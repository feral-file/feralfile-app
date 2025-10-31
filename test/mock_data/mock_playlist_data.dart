// Mock data factory for DP1Call (Playlist) objects
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

class MockPlaylistData {
  // Create basic DP1Call object
  static DP1Call create({
    String id = 'playlist_1',
    String slug = 'test-playlist',
    String title = 'Test Playlist',
    String dpVersion = '1.0.0',
    DateTime? created,
    Map<String, dynamic>? defaults,
    List<DP1Item> items = const [],
    String signature = 'test-signature',
  }) {
    return DP1Call(
      dpVersion: dpVersion,
      id: id,
      slug: slug,
      title: title,
      created: created ?? DateTime.parse('2024-01-01T00:00:00Z'),
      defaults: defaults,
      items: items,
      signature: signature,
    );
  }

  // Create list of playlists
  static List<DP1Call> createList({
    int count = 20,
    String idPrefix = 'playlist',
  }) {
    return List.generate(count, (index) {
      final id = '${idPrefix}_${index + 1}';
      return create(
        id: id,
        slug: id.replaceAll('_', '-'),
        title: 'Playlist ${index + 1}',
        signature: 'sig-${index + 1}',
      );
    });
  }

  // Create single playlist
  static DP1Call createSingle({
    String id = 'single_playlist',
  }) {
    return create(
      id: id,
      slug: 'single-playlist',
      title: 'Single Playlist',
      signature: 'single-sig',
    );
  }

  // Create playlist with items
  static DP1Call createWithItems({
    String id = 'playlist_with_items',
    String title = 'Playlist with Items',
    List<DP1Item> items = const [],
  }) {
    return create(
      id: id,
      slug: 'playlist-with-items',
      title: title,
      items: items,
      signature: 'playlist-with-items-sig',
    );
  }

  // Create playlist with defaults
  static DP1Call createWithDefaults({
    String id = 'playlist_with_defaults',
    String title = 'Playlist with Defaults',
    Map<String, dynamic>? defaults,
  }) {
    return create(
      id: id,
      slug: 'playlist-with-defaults',
      title: title,
      defaults: defaults ??
          {
            'display': {
              'scaling': 'fit',
              'background': '#000000',
            }
          },
      signature: 'defaults-sig',
    );
  }

  // Create minimal playlist
  static DP1Call createMinimal({
    String id = 'minimal_playlist',
  }) {
    return create(
      id: id,
      slug: 'minimal-playlist',
      title: 'Minimal Playlist',
      signature: 'minimal-sig',
    );
  }

  // Create playlist with specific version
  static DP1Call createWithVersion({
    String id = 'versioned_playlist',
    String title = 'Versioned Playlist',
    String dpVersion = '2.0.0',
  }) {
    return create(
      id: id,
      slug: 'versioned-playlist',
      title: title,
      dpVersion: dpVersion,
      signature: 'versioned-sig',
    );
  }

  // Create playlist with recent creation date
  static DP1Call createRecent({
    String id = 'recent_playlist',
    String title = 'Recent Playlist',
    int daysAgo = 1,
  }) {
    final created = DateTime.now().subtract(Duration(days: daysAgo));
    return create(
      id: id,
      slug: 'recent-playlist',
      title: title,
      created: created,
      signature: 'recent-sig',
    );
  }

  // Create playlist with complex defaults
  static DP1Call createWithComplexDefaults({
    String id = 'complex_playlist',
    String title = 'Complex Playlist',
  }) {
    return create(
      id: id,
      slug: 'complex-playlist',
      title: title,
      defaults: {
        'display': {
          'scaling': 'cover',
          'background': '#ffffff',
          'interaction': {
            'keyboard': ['Space', 'ArrowUp', 'ArrowDown'],
            'mouse': {
              'click': true,
              'scroll': true,
              'drag': false,
              'hover': true,
            }
          }
        },
        'audio': {
          'volume': 0.8,
          'autoplay': false,
        }
      },
      signature: 'complex-sig',
    );
  }

  // Create playlist with long title
  static DP1Call createWithLongTitle({
    String id = 'long_title_playlist',
  }) {
    return create(
      id: id,
      slug: 'long-title-playlist',
      title:
          'This is a very long playlist title that contains many words and descriptions to test how the system handles lengthy titles',
      signature: 'long-title-sig',
    );
  }

  // Create empty playlist list
  static List<DP1Call> createEmpty() => [];

  // Create playlists with different versions
  static List<DP1Call> createWithDifferentVersions({
    List<String> versions = const ['1.0.0', '1.1.0', '2.0.0'],
  }) {
    return versions.map((version) {
      return createWithVersion(
        id: 'playlist_v${version.replaceAll('.', '_')}',
        title: 'Playlist v$version',
        dpVersion: version,
      );
    }).toList();
  }

  // Create playlists with different creation dates
  static List<DP1Call> createWithDifferentDates({
    int count = 3,
  }) {
    return List.generate(count, (index) {
      final daysAgo = (index + 1) * 5; // 5, 10, 15 days ago
      return createRecent(
        id: 'playlist_${index + 1}',
        title: 'Playlist ${index + 1}',
        daysAgo: daysAgo,
      );
    });
  }

  // Create playlist with empty items
  static DP1Call createWithEmptyItems({
    String id = 'empty_items_playlist',
    String title = 'Empty Items Playlist',
  }) {
    return createWithItems(
      id: id,
      title: title,
      items: [],
    );
  }
}
