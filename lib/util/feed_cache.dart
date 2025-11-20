import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/service/dp1_store.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:collection/collection.dart';

/*
    This class is used to cache the data from the Feed Server.
  It is used to avoid making unnecessary API calls.
  It is used to cache the data from the API.
  */

abstract class BaseFeedCache {
  final String baseUrl;

  BaseFeedCache({required this.baseUrl});

  Future<void> init({
    required FutureOr<void> Function(Object)? onPlaylistError,
    required FutureOr<void> Function(Object)? onChannelError,
  });
  /*
  =======================================================================

  Playlist operations

  =======================================================================
  */
  DP1Call? getPlaylistById(String playlistId);

  List<DP1Call> getAllPlaylists();

  List<DP1Call> getPlaylistsOfChannel(String channelId);

  void insertListPlaylists(List<DP1Call> playlists);

  void removePlaylistById(String playlistId);

  /*
  =======================================================================

  Channel operations
  */
  Channel? getChannelById(String channelId);

  List<Channel> getAllChannels();

  Channel? getChannelByPlaylistId(String playlistId);

  void insertListChannels(List<Channel> channels);

  void removeChannelById(String channelId);

  /*
  =======================================================================
  */
  void clearAll();

  void clearPlaylists();

  void clearChannels();

  /*
  =======================================================================

  URL operations
  */
}

class FeedCacheImpl extends BaseFeedCache {
  FeedCacheImpl({required String baseUrl}) : super(baseUrl: baseUrl) {
    // Initialize Hive stores and preload cached data
  }

  @override
  Future<void> init({
    required FutureOr<void> Function(Object)? onPlaylistError,
    required FutureOr<void> Function(Object)? onChannelError,
  }) async {
    await _initializeStores(
      onPlaylistError: onPlaylistError,
      onChannelError: onChannelError,
    );
  }

  // Cache: playlist URL -> playlistId (inverted map)
  final Map<String, Channel> _channels = <String, Channel>{};
  final Map<String, DP1Call> _playlists = <String, DP1Call>{};

  late final DP1PlaylistStore _playlistStore;
  late final DP1ChannelStore _channelStore;

  Future<void> _initializeStores({
    required FutureOr<void> Function(Object)? onPlaylistError,
    required FutureOr<void> Function(Object)? onChannelError,
  }) async {
    Object? playlistError;
    Object? channelError;
    try {
      _playlistStore = DP1PlaylistStore(baseUrl: baseUrl);
      _channelStore = DP1ChannelStore(baseUrl: baseUrl);
      await _channelStore.init();
      await _playlistStore.init();

      // Preload channels
      for (final String channelJson in _channelStore.getAll()) {
        try {
          final Map<String, dynamic> data =
              json.decode(channelJson) as Map<String, dynamic>;
          final Channel channel = Channel.fromJson(data);
          _insertChannel(channel);
        } catch (e) {
          channelError = e;
          log.info('Failed to load channel from Hive: $e');
        }
      }

      // Preload playlists
      for (final String playlistJson in _playlistStore.getAll()) {
        try {
          final Map<String, dynamic> data =
              json.decode(playlistJson) as Map<String, dynamic>;
          final DP1Call playlist = DP1Call.fromJson(data);
          _insertPlaylist(playlist);
        } catch (e) {
          playlistError = e;
          log.info('Failed to load playlist from Hive: $e');
        }
      }
      log.info('Loaded playlist from Hive for $baseUrl');
    } catch (e) {
      log.info('Failed to initialize DP1 stores: $e');
      playlistError ??= e;
      channelError ??= e;
    } finally {
      if (playlistError != null) {
        log.info('Failed to load playlist from Hive: $playlistError');
        onPlaylistError?.call(playlistError);
      }
      if (channelError != null) {
        onChannelError?.call(channelError);
      }
    }
  }

  bool get hasCache => _playlists.isNotEmpty || _channels.isNotEmpty;

  // get playlist by url
  DP1Call? _getPlaylistByUrl(String url) {
    try {
      final playlistId = url.playlistId;
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
  List<DP1Call> getAllPlaylists() =>
      _playlists.values.toList().sortedBy((e) => e.created);

  /* 
  =======================================================================

  Channel operations

  =======================================================================
  */

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

  @override
  void removeChannelById(String channelId) {
    _channels.remove(channelId);
    // remove all playlists of channel
    final playlists = getPlaylistsOfChannel(channelId);
    for (final p in playlists) {
      removePlaylistById(p.id);
    }
    _onCacheUpdated();
  }

  // add Playlist to cache
  void _insertPlaylist(DP1Call playlist) {
    _playlists[playlist.id] = playlist;
    try {
      _playlistStore.save(json.encode(playlist.toJson()), playlist.id);
    } catch (_) {}
  }

  @override
  void insertListPlaylists(List<DP1Call> playlists) {
    for (int i = 0; i < playlists.length; i++) {
      _insertPlaylist(playlists[i]);
    }
    _onCacheUpdated();
  }

  @override
  void removePlaylistById(String playlistId) {
    _playlists.remove(playlistId);
    _onCacheUpdated();
  }

  // Clear operations (optional)
  @override
  void clearAll() {
    clearPlaylists();
    clearChannels();
    _onCacheUpdated();
  }

  @override
  void clearPlaylists() {
    _playlists.clear();
    unawaited(_playlistStore.clear());
    _onCacheUpdated();
  }

  @override
  void clearChannels() {
    _channels.clear();
    unawaited(_channelStore.clear());
    _onCacheUpdated();
  }

  void _onCacheUpdated() {
    injector<ChannelsBloc>().add(const LoadChannelsEvent());
    injector<PlaylistsBloc>(
            instanceName: PlaylistsBlocInstance.curated.instanceName)
        .add(const LoadPlaylistsEvent());
    injector<PlaylistsBloc>(instanceName: PlaylistsBlocInstance.my.instanceName)
        .add(const LoadPlaylistsEvent());
    injector<PlaylistsBloc>(
            instanceName: PlaylistsBlocInstance.global.instanceName)
        .add(const LoadPlaylistsEvent());
  }
}
