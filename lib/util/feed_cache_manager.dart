import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:collection/collection.dart';

/*
    This class is used to cache the data from the Feed Server.
  It is used to avoid making unnecessary API calls.
  It is used to cache the data from the API.
  */
class FeedCacheManager {
  FeedCacheManager._internal();
  static final FeedCacheManager _instance = FeedCacheManager._internal();
  factory FeedCacheManager() => _instance;

  // Cache: playlist URL -> playlistId (inverted map)
  final Map<String, String> _urlToPlaylistId = <String, String>{};
  final Map<String, Channel> _channels = <String, Channel>{};
  final Map<String, DP1Call> _playlists = <String, DP1Call>{};

  // get playlist by url
  DP1Call? _getPlaylistByUrl(String url) {
    try {
      final playlistId = _urlToPlaylistId[url];
      if (playlistId == null) return null;
      return getPlaylistById(playlistId);
    } catch (_) {
      return null;
    }
  }

  /* 
  =======================================================================

  Playlist operations

  =======================================================================
  */

  // get playlist by id
  DP1Call? getPlaylistById(String playlistId) => _playlists[playlistId];

  // get playlists of channel
  List<DP1Call> getPlaylistsOfChannel(String channelId) {
    final channel = getChannelById(channelId);
    if (channel == null) return [];
    return channel.playlists.map(_getPlaylistByUrl).nonNulls.toList();
  }

  // get all playlists
  List<DP1Call> getAllPlaylists() => _playlists.values.toList();

  /* 
  =======================================================================

  Channel operations

  =======================================================================
  */

  void setChannels(List<Channel> channels) {
    for (final c in channels) {
      _channels[c.id] = c;
    }
  }

  List<Channel> getAllChannels() => _channels.values.toList();

  Channel? getChannelById(String channelId) => _channels[channelId];

  Channel? getChannelByPlaylistId(String playlistId) {
    return _channels.values
        .firstWhereOrNull((channel) => channel.playlists.contains(playlistId));
  }

  /*
  =======================================================================

  Cache operations

  =======================================================================
   */

  // add Channel to cache
  void addChannelToCache(Channel channel) {
    _channels[channel.id] = channel;
  }

  void addListChannelsToCache(List<Channel> channels) {
    for (final c in channels) {
      addChannelToCache(c);
    }
  }

  // add Playlist to cache
  void addPlaylistToCache(DP1Call playlist, {String? url}) {
    _playlists[playlist.id] = playlist;
    if (url != null) {
      _urlToPlaylistId[url] = playlist.id;
    }
  }

  void addListPlaylistsToCache(List<DP1Call> playlists, {List<String>? urls}) {
    for (int i = 0; i < playlists.length; i++) {
      addPlaylistToCache(playlists[i], url: urls?[i]);
    }
  }

  Future<void> reloadCache() async {
    final playlists =
        await injector<DP1FeedService>().getAllPlaylists(usingCache: false);
    final channels =
        await injector<DP1FeedService>().getAllChannels(usingCache: false);
    addListChannelsToCache(channels.items);
    addListPlaylistsToCache(playlists.items);
  }

  // Clear operations (optional)
  void clearAll() {
    _urlToPlaylistId.clear();
    _playlists.clear();
    _channels.clear();
  }
}
