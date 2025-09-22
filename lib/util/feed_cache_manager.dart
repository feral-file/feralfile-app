import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/dp1_store.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

/*
    This class is used to cache the data from the Feed Server.
  It is used to avoid making unnecessary API calls.
  It is used to cache the data from the API.
  */
class FeedCacheManager {
  FeedCacheManager._internal() {
    // Listen to app foreground/background changes and reload cache on resume
    _fgbgSubscription ??=
        FGBGEvents.instance.stream.listen((FGBGType event) async {
      if (event == FGBGType.foreground) {
        if (injector<RemoteConfigService>().isLoaded) {
          await reloadCache();
        }
      }
    });

    // Initialize Hive stores and preload cached data
    _initializeStores();
  }
  static final FeedCacheManager _instance = FeedCacheManager._internal();
  factory FeedCacheManager() => _instance;

  // Cache: playlist URL -> playlistId (inverted map)
  final Map<String, String> _urlToPlaylistId = <String, String>{};
  final Map<String, Channel> _channels = <String, Channel>{};
  final Map<String, DP1Call> _playlists = <String, DP1Call>{};
  StreamSubscription<FGBGType>? _fgbgSubscription;

  final DP1PlaylistStore _playlistStore = DP1PlaylistStore();
  final DP1ChannelStore _channelStore = DP1ChannelStore();
  final DP1UrlToPlaylistMapStore _urlMapStore = DP1UrlToPlaylistMapStore();

  Future<void> _initializeStores() async {
    try {
      await _channelStore.init('');
      await _playlistStore.init('');
      await _urlMapStore.init('');

      // Preload channels
      for (final String channelJson in _channelStore.getAll()) {
        try {
          final Map<String, dynamic> data =
              json.decode(channelJson) as Map<String, dynamic>;
          final Channel channel = Channel.fromJson(data);
          addChannelToCache(channel);
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
          addPlaylistToCache(playlist);
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
    // Persist to Hive store
    try {
      _channelStore.save(json.encode(channel.toJson()), channel.id);
    } catch (_) {}
  }

  void addListChannelsToCache(List<Channel> channels) {
    for (final c in channels) {
      addChannelToCache(c);
    }
  }

  // add Playlist to cache
  void addPlaylistToCache(DP1Call playlist, {String? url}) {
    _playlists[playlist.id] = playlist;
    try {
      _playlistStore.save(json.encode(playlist.toJson()), playlist.id);
    } catch (_) {}

    if (url != null) {
      _urlToPlaylistId[url] = playlist.id;
      _persistUrlMap();
    }
    // Persist to Hive store
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
    _onCacheUpdated();
  }

  // Clear operations (optional)
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
}
