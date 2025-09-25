import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/util/feed_cache_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

class DP1FeedService {
  DP1FeedService(this.api, this._feedCacheManager);

  final DP1FeedApi api;

  final FeedCacheManager _feedCacheManager;

  // List<String>? get remoteConfigChannelIds => [];
  // injector<RemoteConfigService>()
  //     .getConfig<List<dynamic>?>(
  //         ConfigGroup.dp1Playlist, ConfigKey.dp1PlaylistChannelIds, null)
  //     ?.cast<String>();

  List<String>? get remoteConfigChannelUrls => [
        'https://dp1-feed-operator-api-prod.autonomy-system.workers.dev/api/v1/channels/dae709d7-26da-4b4c-b881-39cd681cc82f',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/cb3455c2-7122-4414-a9f5-7ccbe434de21',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/5b467722-202d-44d2-af77-4c438c7f2258',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/21f9b1a1-7ad6-4752-ba2c-3f675c4dea63',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/92c75624-10ee-403b-81eb-0da0011d4dde',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/70930b59-04cc-49e0-a982-7ffc17210add',
      ];

  /*
  =======================================================================

  PLAYLIST
  Api for playlist
  
  =======================================================================
  */

  // create playlist
  Future<DP1Call> createPlaylist(
      {required DP1CreatePlaylistRequest request,
      bool isSyncToCloud = true}) async {
    final created = await api.createPlaylist(request.toJson());
    try {
      if (isSyncToCloud) {
        final cloud = injector<CloudManager>().dp1FeedCloudObject;
        await cloud.insertPlaylists([created]);
      }
    } catch (e) {
      // Keep API success even if cloud sync fails
      log.info('Failed to cache created DP1 playlist to cloud: $e');
    }
    return created;
  }

  // update playlist
  Future<DP1Call> updatePlaylist(
      {required String playlistId,
      required DP1CreatePlaylistRequest request,
      bool isSyncToCloud = true}) async {
    final updatedPlaylist =
        await api.updatePlaylist(playlistId, request.toJson());
    return updatedPlaylist;
  }

  // get playlist by id
  Future<DP1Call> getPlaylistById(String playlistId,
      {bool usingCache = true}) async {
    if (usingCache) {
      final cachedPlaylist = _feedCacheManager.getPlaylistById(playlistId);
      if (cachedPlaylist != null) return cachedPlaylist;
    }
    final result = await api.getPlaylistById(playlistId);
    return result;
  }

  Future<List<DP1Call>> getPlaylistsByChannel(Channel channel,
      {bool usingCache = true}) async {
    // find in cache, if not found, fetch from api
    if (usingCache) {
      final cachedPlaylists =
          _feedCacheManager.getPlaylistsOfChannel(channel.id);
      return cachedPlaylists;
    }

    final dio = Dio();
    final futures = channel.playlists.map((playlistUrl) async {
      try {
        final response = await dio.get<Map<String, dynamic>>(playlistUrl);
        if (response.statusCode == 200 && response.data != null) {
          final playlist = DP1Call.fromJson(response.data!);
          _feedCacheManager.addPlaylistToCache(playlist, url: playlistUrl);
          return playlist;
        }
      } catch (e) {
        log.info('Error when get playlists from channel ${channel.title}: $e');
        return null;
      }
    });
    final results = await Future.wait(futures);
    final playlists = results.nonNulls.toList();
    return playlists;
  }

  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedPlaylists =
          _feedCacheManager.getPlaylistsOfChannel(channelId);
      if (cachedPlaylists.isNotEmpty) {
        return DP1PlaylistResponse(cachedPlaylists, false, null);
      }
    }
    final resp = await api.getAllPlaylists(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
    return resp;
  }

  Future<DP1PlaylistResponse> getAllPlaylists({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedPlaylists = _feedCacheManager.getAllPlaylists();
      if (cachedPlaylists.isNotEmpty) {
        return DP1PlaylistResponse(cachedPlaylists, false, null);
      }
    }

    // final remoteChannelIds = remoteConfigChannelIds;
    final remoteChannelUrls = remoteConfigChannelUrls;

    if (remoteConfigChannelUrls != null) {
      final channels = (await getChannelsByUrls(
              channelUrls: remoteChannelUrls!, usingCache: usingCache))
          .values
          .toList();
      final futures = channels.map((c) async {
        return getPlaylistsByChannel(c, usingCache: usingCache);
      });
      final results = await Future.wait(futures);
      final playlists = results.expand((list) => list).toList();
      _feedCacheManager.addListPlaylistsToCache(playlists);
      return DP1PlaylistResponse(playlists, false, null);
    } else {
      final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
      _feedCacheManager.addListPlaylistsToCache(resp.items);
      return resp;
    }
  }

  /*
  =======================================================================

  CHANNEL
  Api for channel

  =======================================================================
  */

  Channel? getChannelByPlaylistId(String playlistId) {
    final channel = _feedCacheManager.getChannelByPlaylistId(playlistId);
    return channel;
  }

  Future<Channel> getChannelDetail(String channelId,
      {bool usingCache = true}) async {
    if (usingCache) {
      final cached = _feedCacheManager.getChannelById(channelId);
      if (cached != null) return cached;
    }
    final channel = await api.getChannelById(channelId);
    return channel;
  }

  // Future<List<Channel>> getChannelsByIds({
  //   required List<String> channelIds,
  //   bool usingCache = true,
  // }) async {
  //   final futures = channelIds.map((id) async {
  //     return getChannelDetail(id, usingCache: usingCache);
  //   });
  //   final channels = await Future.wait(futures);
  //   return channels;
  // }

  Future<Map<String, Channel>> getChannelsByUrls({
    required List<String> channelUrls,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedChannels = _feedCacheManager.getChannelsByUrls(channelUrls);
      if (cachedChannels.isNotEmpty) {
        return cachedChannels;
      }
    }
    final dio = Dio();
    final futures = channelUrls.map((url) async {
      try {
        final response = await dio.get<Map<String, dynamic>>(url);
        if (response.statusCode == 200 && response.data != null) {
          final channel = Channel.fromJson(response.data!);
          _feedCacheManager.setChannels([channel]);
          return MapEntry(url, channel);
        }
      } catch (e) {
        log.info('Error when get channel from url $url: $e');
        return null;
      }
    });
    final results = await Future.wait(futures);
    final map = <String, Channel>{};
    for (final result in results) {
      if (result == null) continue;
      map[result.key] = result.value;
    }
    return map;
  }

  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    // final remoteChannelIds = remoteConfigChannelIds;
    final remoteChannelUrls = remoteConfigChannelUrls;

    if (remoteChannelUrls != null) {
      final channels = await getChannelsByUrls(
          channelUrls: remoteChannelUrls, usingCache: usingCache);
      if (channels.isNotEmpty) {
        return DP1ChannelsResponse(
          channels.values.toList(),
          false, // hasMore is false because we fetched all remote config channels
          null, // cursor is null because we fetched all channels
        );
      }
    }

    // if not remote channel ids, get all channels from api
    String? currentCursor = cursor;

    if (usingCache) {
      final cachedChannels = _feedCacheManager.getAllChannels();
      return DP1ChannelsResponse(
        cachedChannels,
        false, // hasMore is false because we fetched all remote config channels
        null, // cursor is null because we fetched all channels
      );
    } else {
      final channels = await api.getAllChannels(
        cursor: currentCursor,
        limit: limit,
      );
      currentCursor = channels.cursor;
      channels.items.sort(
        (channel1, channel2) => channel1.created.compareTo(
          channel2.created,
        ),
      );
      channels.items.removeWhere(
        (channel) => !(remoteChannelUrls?.contains(channel.id) ?? true),
      );

      _feedCacheManager.addListChannelsToCache(channels.items);

      return DP1ChannelsResponse(
        channels.items,
        channels.hasMore,
        channels.cursor,
      );
    }
  }

/*
  =======================================================================

  Playlist Item

  =======================================================================
*/

  Future<DP1PlaylistItemsResponse> getPlaylistItemsOfChannel({
    required String channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    return api.getPlaylistItems(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
  }

  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    return api.getPlaylistItems(
      cursor: cursor,
      limit: limit,
    );
  }

// OWNED PLAYLIST
// Api for owned playlist
//

  Future<bool> deletePlaylist(String id) async {
    await api.deletePlaylist(id);
    return true;
  }
}
