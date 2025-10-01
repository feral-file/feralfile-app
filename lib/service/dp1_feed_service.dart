import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

abstract class FeralFileDP1FeedServiceBase extends BaseDP1FeedService {
  FeralFileDP1FeedServiceBase();

  List<String>? get remoteConfigChannelIds;

  /*
  =======================================================================

  PLAYLIST

  =======================================================================
  */

  Future<List<DP1Call>> getPlaylistsByChannel(
    Channel channel, {
    bool usingCache = true,
  });

  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  });

  /*
  =======================================================================

  CHANNEL

  =======================================================================
  */

  Channel? getChannelByPlaylistId(String playlistId);

  Future<Channel> getChannelDetail(String channelId, {bool usingCache = true});

  Future<List<Channel>> getChannelsByIds({
    required List<String> channelIds,
    bool usingCache = true,
  });

  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
    bool usingCache = true,
  });

  /*
  =======================================================================

  PLAYLIST ITEMS

  =======================================================================
  */

  Future<DP1PlaylistItemsResponse> getPlaylistItemsOfChannel({
    required String channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  });
}

class FeralFileDP1FeedService extends BaseDP1FeedServiceImpl
    implements FeralFileDP1FeedServiceBase {
  FeralFileDP1FeedService(super.api, super.feedCacheManager) : super();

  @override
  List<String>? get remoteConfigChannelIds => injector<RemoteConfigService>()
      .getConfig<List<dynamic>?>(
        ConfigGroup.dp1Playlist,
        ConfigKey.dp1PlaylistChannelIds,
        null,
      )
      ?.cast<String>();

  /*
  =======================================================================

  PLAYLIST
  
  =======================================================================
  */

  @override
  Future<List<DP1Call>> getPlaylistsByChannel(
    Channel channel, {
    bool usingCache = true,
  }) async {
    // find in cache, if not found, fetch from api
    if (usingCache) {
      final cachedPlaylists =
          feedCacheManager.getPlaylistsOfChannel(channel.id);
      return cachedPlaylists;
    }

    final dio = Dio();
    final futures = channel.playlists.map((playlistUrl) async {
      try {
        final response = await dio.get<Map<String, dynamic>>(playlistUrl);
        if (response.statusCode == 200 && response.data != null) {
          final playlist = DP1Call.fromJson(response.data!);
          feedCacheManager.addPlaylistToCache(playlist, url: playlistUrl);
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

  @override
  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedPlaylists = feedCacheManager.getPlaylistsOfChannel(channelId);
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

  @override
  Future<DP1PlaylistResponse> getAllPlaylists({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedPlaylists = feedCacheManager.getAllPlaylists();
      if (cachedPlaylists.isNotEmpty) {
        return DP1PlaylistResponse(cachedPlaylists, false, null);
      }
    }

    final remoteChannelIds = remoteConfigChannelIds;

    if (remoteChannelIds != null) {
      final channels = await getChannelsByIds(
        channelIds: remoteChannelIds,
        usingCache: usingCache,
      );
      final futures = channels.map((c) async {
        return getPlaylistsByChannel(c, usingCache: usingCache);
      });
      final results = await Future.wait(futures);
      final playlists = results.expand((list) => list).toList();
      feedCacheManager.addListPlaylistsToCache(playlists);
      return DP1PlaylistResponse(playlists, false, null);
    } else {
      final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
      feedCacheManager.addListPlaylistsToCache(resp.items);
      return resp;
    }
  }

  /*
  =======================================================================

  CHANNEL

  =======================================================================
  */

  @override
  Channel? getChannelByPlaylistId(String playlistId) {
    final channel = feedCacheManager.getChannelByPlaylistId(playlistId);
    return channel;
  }

  @override
  Future<Channel> getChannelDetail(
    String channelId, {
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cached = feedCacheManager.getChannelById(channelId);
      if (cached != null) return cached;
    }
    final channel = await api.getChannelById(channelId);
    return channel;
  }

  @override
  Future<List<Channel>> getChannelsByIds({
    required List<String> channelIds,
    bool usingCache = true,
  }) async {
    final futures = channelIds.map((id) async {
      return getChannelDetail(id, usingCache: usingCache);
    });
    final channels = await Future.wait(futures);
    return channels;
  }

  @override
  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    final remoteChannelIds = remoteConfigChannelIds;

    if (remoteChannelIds != null) {
      final channels = await getChannelsByIds(
        channelIds: remoteChannelIds,
        usingCache: usingCache,
      );
      if (channels.isNotEmpty) {
        feedCacheManager.addListChannelsToCache(channels);
        return DP1ChannelsResponse(
          channels,
          false, // hasMore is false because we fetched all remote config channels
          null, // cursor is null because we fetched all channels
        );
      }
    }

    // if not remote channel ids, get all channels from api
    String? currentCursor = cursor;

    if (usingCache) {
      final cachedChannels = feedCacheManager.getAllChannels();
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
        (channel) => !(remoteChannelIds?.contains(channel.id) ?? true),
      );

      feedCacheManager.addListChannelsToCache(channels.items);

      return DP1ChannelsResponse(
        channels.items,
        channels.hasMore,
        channels.cursor,
      );
    }
  }

  /*
  =======================================================================

  PLAYLIST ITEMS

  =======================================================================
  */

  @override
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
}
