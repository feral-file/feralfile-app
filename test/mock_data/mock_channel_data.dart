// Mock data factory for Channel objects
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';

class MockChannelData {
  // Create basic Channel object
  static Channel create({
    String id = 'channel_1',
    String slug = 'test-channel',
    String title = 'Test Channel',
    String? curator,
    String? summary,
    List<String> playlists = const [],
    DateTime? created,
    String? coverImage,
  }) {
    return Channel(
      id: id,
      slug: slug,
      title: title,
      curator: curator,
      summary: summary,
      playlists: playlists,
      created: created ?? DateTime.parse('2024-01-01T00:00:00Z'),
      coverImage: coverImage,
    );
  }

  // Create list of channels
  static List<Channel> createList({
    int count = 20,
    String idPrefix = 'channel',
  }) {
    return List.generate(count, (index) {
      final id = '${idPrefix}_${index + 1}';
      return create(
        id: id,
        slug: id.replaceAll('_', '-'),
        title: 'Channel ${index + 1}',
        curator: 'Curator ${index + 1}',
        summary: 'Test channel ${index + 1} description',
      );
    });
  }

  // Create single channel
  static Channel createSingle({
    String id = 'single_channel',
  }) {
    return create(
      id: id,
      slug: 'single-channel',
      title: 'Single Channel',
      curator: 'Single Curator',
      summary: 'A single test channel',
    );
  }

  // Create channel with playlists
  static Channel createWithPlaylists({
    String id = 'channel_with_playlists',
    String title = 'Channel with Playlists',
    List<String> playlistIds = const ['playlist_1', 'playlist_2'],
  }) {
    return create(
      id: id,
      slug: 'channel-with-playlists',
      title: title,
      playlists: playlistIds,
      curator: 'Test Curator',
      summary: 'A channel containing multiple playlists',
    );
  }

  // Create channel with cover image
  static Channel createWithCoverImage({
    String id = 'channel_with_cover',
    String title = 'Channel with Cover',
    String coverImageUrl = 'https://example.com/cover.jpg',
  }) {
    return create(
      id: id,
      slug: 'channel-with-cover',
      title: title,
      curator: 'Cover Curator',
      coverImage: coverImageUrl,
    );
  }

  // Create minimal channel
  static Channel createMinimal({
    String id = 'minimal_channel',
  }) {
    return create(
      id: id,
      slug: 'minimal-channel',
      title: 'Minimal Channel',
    );
  }

  // Create channel with specific curator
  static Channel createWithCurator({
    String id = 'curated_channel',
    String title = 'Curated Channel',
    String curator = 'Famous Curator',
  }) {
    return create(
      id: id,
      slug: 'curated-channel',
      title: title,
      curator: curator,
      summary: 'A channel curated by $curator',
    );
  }

  // Create channel with recent creation date
  static Channel createRecent({
    String id = 'recent_channel',
    String title = 'Recent Channel',
    int daysAgo = 1,
  }) {
    final created = DateTime.now().subtract(Duration(days: daysAgo));
    return create(
      id: id,
      slug: 'recent-channel',
      title: title,
      created: created,
      curator: 'Recent Curator',
    );
  }

  // Create channel with long summary
  static Channel createWithLongSummary({
    String id = 'detailed_channel',
    String title = 'Detailed Channel',
  }) {
    return create(
      id: id,
      slug: 'detailed-channel',
      title: title,
      curator: 'Detail Curator',
      summary:
          'This is a very detailed summary that contains a lot of information about the channel, its purpose, and what kind of content it showcases. It provides comprehensive details for testing purposes.',
    );
  }

  // Create empty channel list
  static List<Channel> createEmpty() => [];

  // Create channels with different creation dates
  static List<Channel> createWithDifferentDates({
    int count = 3,
  }) {
    return List.generate(count, (index) {
      final daysAgo = (index + 1) * 7; // 7, 14, 21 days ago
      return createRecent(
        id: 'channel_${index + 1}',
        title: 'Channel ${index + 1}',
        daysAgo: daysAgo,
      );
    });
  }
}
