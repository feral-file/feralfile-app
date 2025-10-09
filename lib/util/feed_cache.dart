import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/service/dp1_store.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';

/*
    This class is used to cache the data from the Feed Server.
  It is used to avoid making unnecessary API calls.
  It is used to cache the data from the API.
  */

abstract class BaseFeedCache {
  final String baseUrl;

  BaseFeedCache({required this.baseUrl});

  Future<void> init();
  /*
  =======================================================================

  Playlist operations

  =======================================================================
  */
  DP1Call? getPlaylistById(String playlistId);
  List<DP1Call> getAllPlaylists();
  List<DP1Call> getPlaylistsOfChannel(String channelId);
  void insertListPlaylists(List<DP1Call> playlists, {List<String>? urls});

  /*
  =======================================================================

  Channel operations
  */
  Channel? getChannelById(String channelId);
  List<Channel> getAllChannels();
  Map<String, Channel> getChannelsByUrls(List<String> channelUrls);
  Channel? getChannelByPlaylistId(String playlistId);
  void insertListChannels(List<Channel> channels);

  /*
  =======================================================================
  */
  void clearAll();

  /*
  =======================================================================

  URL operations
  */
}

class FeedCacheImpl extends BaseFeedCache {
  FeedCacheImpl({required String baseUrl}) : super(baseUrl: baseUrl) {
    // Initialize Hive stores and preload cached data
    _initializeStores();
  }

  @override
  Future<void> init() async {
    await _initializeStores();
  }

  // Cache: playlist URL -> playlistId (inverted map)
  final Map<String, String> _urlToPlaylistId = <String, String>{};
  final Map<String, Channel> _channels = <String, Channel>{};
  final Map<String, DP1Call> _playlists = <String, DP1Call>{};

  late final DP1PlaylistStore _playlistStore;
  late final DP1ChannelStore _channelStore;
  late final DP1UrlToPlaylistMapStore _urlMapStore;

  Future<void> _initializeStores() async {
    try {
      _playlistStore = DP1PlaylistStore(baseUrl: baseUrl);
      _channelStore = DP1ChannelStore(baseUrl: baseUrl);
      _urlMapStore = DP1UrlToPlaylistMapStore(baseUrl: baseUrl);
      await _channelStore.init();
      await _playlistStore.init();
      await _urlMapStore.init();

      // Preload channels
      for (final String channelJson in _channelStore.getAll()) {
        try {
          final Map<String, dynamic> data =
              json.decode(channelJson) as Map<String, dynamic>;
          final Channel channel = Channel.fromJson(data);
          _insertChannel(channel);
        } catch (e) {
          log.info('Failed to load channel from Hive: $e');
        }
      }

      // Preload playlists
      // Preload URL map
      try {
        final String? jsonMap =
            _urlMapStore.get(DP1UrlToPlaylistMapStore.objectId);
        if (jsonMap != null && jsonMap.isNotEmpty) {
          final Map<String, dynamic> data =
              json.decode(jsonMap) as Map<String, dynamic>;
          _urlToPlaylistId.clear();
          data.forEach((key, value) {
            if (value is String) {
              _urlToPlaylistId[key] = value;
            }
          });
        }
      } catch (e) {
        log.info('Failed to load url->playlistId map from Hive: $e');
      }
      for (final String playlistJson in _playlistStore.getAll()) {
        try {
          final Map<String, dynamic> data =
              json.decode(playlistJson) as Map<String, dynamic>;
          final DP1Call playlist = DP1Call.fromJson(data);
          _insertPlaylist(playlist);
        } catch (e) {
          log.info('Failed to load playlist from Hive: $e');
        }
      }
    } catch (e) {
      log.info('Failed to initialize DP1 stores: $e');
    }
  }

  bool get hasCache => _playlists.isNotEmpty || _channels.isNotEmpty;

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
  @override
  DP1Call? getPlaylistById(String playlistId) => _playlists[playlistId];

  // get playlists of channel
  @override
  List<DP1Call> getPlaylistsOfChannel(String channelId) {
    final channel = getChannelById(channelId);
    if (channel == null) return [];
    return channel.playlists.map(_getPlaylistByUrl).nonNulls.toList();
  }

  // get all playlists
  @override
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

  void setChannelWithUrls(Channel channel, String url) {
    _channels[url] = channel;
    _persistUrlMap();
  }

  @override
  List<Channel> getAllChannels() => _channels.values.toList();

  @override
  Channel? getChannelById(String channelId) => _channels[channelId];

  @override
  Channel? getChannelByPlaylistId(String playlistId) {
    return _channels.values.firstWhereOrNull(
        (channel) => channel.playlists.any((url) => url.contains(playlistId)));
  }

  /*
  =======================================================================

  Cache operations

  =======================================================================
   */

  // add Channel to cache
  void _insertChannel(Channel channel) {
    _channels[channel.id] = channel;
    // Persist to Hive store
    try {
      _channelStore.save(json.encode(channel.toJson()), channel.id);
    } catch (_) {}
  }

  @override
  void insertListChannels(List<Channel> channels) {
    for (final c in channels) {
      _insertChannel(c);
    }
    _onCacheUpdated();
  }

  // add Playlist to cache
  void _insertPlaylist(DP1Call playlist, {String? url}) {
    _playlists[playlist.id] = playlist;
    try {
      _playlistStore.save(json.encode(playlist.toJson()), playlist.id);
    } catch (_) {}

    if (url != null) {
      _urlToPlaylistId[url] = playlist.id;
      _persistUrlMap();
    }
  }

  @override
  void insertListPlaylists(List<DP1Call> playlists, {List<String>? urls}) {
    for (int i = 0; i < playlists.length; i++) {
      _insertPlaylist(playlists[i], url: urls?[i]);
    }
    _onCacheUpdated();
  }

  // Clear operations (optional)
  @override
  void clearAll() {
    _urlToPlaylistId.clear();
    _playlists.clear();
    _channels.clear();
    // Clear persistent stores as well
    unawaited(_channelStore.clear());
    unawaited(_playlistStore.clear());
    unawaited(_urlMapStore.clear());
    _onCacheUpdated();
  }

  void _onCacheUpdated() {
    injector<ChannelsBloc>().add(const LoadChannelsEvent());
    injector<PlaylistsBloc>().add(const LoadPlaylistsEvent());
  }

  void _persistUrlMap() {
    try {
      if (_urlToPlaylistId.isEmpty) {
        _urlMapStore.delete(DP1UrlToPlaylistMapStore.objectId);
        return;
      }
      final String jsonMap = json.encode(_urlToPlaylistId);
      _urlMapStore.save(jsonMap, DP1UrlToPlaylistMapStore.objectId);
    } catch (e) {
      // ignore failures
    }
  }

  @override
  Map<String, Channel> getChannelsByUrls(List<String> channelUrls) {
    final map = <String, Channel>{};
    for (final url in channelUrls) {
      if (_channels[url] == null) continue;
      map[url] = _channels[url]!;
    }
    return map;
  }
}
