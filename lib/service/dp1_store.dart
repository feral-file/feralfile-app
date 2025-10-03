import 'package:autonomy_flutter/service/hive_store_service.dart';

/// Store for DP1 Playlists
///
/// Note: We store serialized data (e.g., JSON string) for playlists.
/// Use `save(jsonString, playlistId)` and `get(playlistId)` to retrieve.
class DP1PlaylistStore extends HiveStoreObjectServiceImpl<String> {
  DP1PlaylistStore({required this.baseUrl})
      : super(key: "${_key}.${baseUrl.replaceFirst('https://', '')}");
  static const String _key = 'dp1.playlists.store';

  final String baseUrl;

  @override
  Future<void> init() async {
    await super.init();
  }
}

/// Store for DP1 Channels
///
/// Note: We store serialized data (e.g., JSON string) for channels.
/// Use `save(jsonString, channelId)` and `get(channelId)` to retrieve.
class DP1ChannelStore extends HiveStoreObjectServiceImpl<String> {
  DP1ChannelStore({required this.baseUrl})
      : super(key: _key + baseUrl.replaceFirst('https://', ''));
  static const String _key = 'dp1.channels.store';

  final String baseUrl;

  @override
  Future<void> init() async {
    await super.init();
  }
}

/// Store for URL -> PlaylistId mapping
///
/// We persist the entire mapping as a single JSON string value
/// under a fixed object id to avoid needing key iteration.
class DP1UrlToPlaylistMapStore extends HiveStoreObjectServiceImpl<String> {
  DP1UrlToPlaylistMapStore({required this.baseUrl})
      : super(key: _key + baseUrl.replaceFirst('https://', ''));
  static const String _key = 'dp1.urlToPlaylistId.store';
  static const String objectId = '__url_map__';

  final String baseUrl;

  @override
  Future<void> init() async {
    await super.init();
  }
}
