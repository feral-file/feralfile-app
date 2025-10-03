import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/util/feed_cache.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

class RemoteConfigChannel {
  RemoteConfigChannel({
    required this.endpoint,
    required this.channelId,
  });
  final String endpoint;
  final String channelId;

  String get url => '$endpoint/api/v1/channels/$channelId';
}

abstract class DP1FeedWithChannelExtensionServiceBase
    extends BaseDP1FeedService {
  DP1FeedWithChannelExtensionServiceBase({required super.baseUrl});

  final List<String> _remoteConfigChannelIds = [];

  void addRemoteConfigChannelIds(List<String> channelIds) {
    _remoteConfigChannelIds.addAll(channelIds);
  }

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

  Future<Map<String, Channel>> getChannelsByUrls({
    required List<String> channelUrls,
    bool usingCache = true,
  });

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

abstract class FeralFileDP1FeedServiceBase
    extends DP1FeedWithChannelExtensionServiceBase {
  FeralFileDP1FeedServiceBase({required super.baseUrl});
}

class FeralFileDP1FeedService extends BaseDP1FeedServiceImpl
    implements FeralFileDP1FeedServiceBase {
  FeralFileDP1FeedService({required super.baseUrl});

  @override
  void initializeApiAndCache(String baseUrl) {
    api = DP1FeedApi.dioBaseUrl(
        baseUrl: baseUrl,
        dio: DioManager().dp1Feed(BaseOptions(
          followRedirects: true,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )));
    cache = FeedCacheImpl(baseUrl: baseUrl);
  }

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
      final cachedPlaylists = cache.getPlaylistsOfChannel(channel.id);
      return cachedPlaylists;
    }

    final dio = Dio();
    final futures = channel.playlists.map((playlistUrl) async {
      try {
        final response = await dio.get<Map<String, dynamic>>(playlistUrl);
        if (response.statusCode == 200 && response.data != null) {
          final playlist = DP1Call.fromJson(response.data!);
          cache.insertListPlaylists([playlist], urls: [playlistUrl]);
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
      final cachedPlaylists = cache.getPlaylistsOfChannel(channelId);
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
      final cachedPlaylists = cache.getAllPlaylists();
      if (cachedPlaylists.isNotEmpty) {
        return DP1PlaylistResponse(cachedPlaylists, false, null);
      }
    }

    if (_remoteConfigChannelIds.isNotEmpty) {
      final channels = (await getChannelsByIds(
          channelIds: _remoteConfigChannelIds, usingCache: usingCache));
      final futures = channels.map((c) async {
        return getPlaylistsByChannel(c, usingCache: usingCache);
      });
      final results = await Future.wait(futures);
      final playlists = results.expand((list) => list).toList();

      cache.insertListPlaylists(playlists);
      return DP1PlaylistResponse(playlists, false, null);
    } else {
      final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
      cache.insertListPlaylists(resp.items);
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
    final channel = cache.getChannelByPlaylistId(playlistId);
    return channel;
  }

  @override
  Future<Channel> getChannelDetail(
    String channelId, {
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cached = cache.getChannelById(channelId);
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
  Future<Map<String, Channel>> getChannelsByUrls({
    required List<String> channelUrls,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedChannels = cache.getChannelsByUrls(channelUrls);
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
          cache.insertListChannels([channel]);
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

  @override
  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (_remoteConfigChannelIds.isNotEmpty) {
      final channels = await getChannelsByIds(
          channelIds: _remoteConfigChannelIds, usingCache: usingCache);
      if (channels.isNotEmpty) {
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
      final cachedChannels = cache.getAllChannels();
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
        (channel) => !(_remoteConfigChannelIds.any((c) => c == channel.id)),
      );

      cache.insertListChannels(channels.items);

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

  @override
  List<String> _remoteConfigChannelIds = [];

  @override
  void addRemoteConfigChannelIds(List<String> channelIds) {
    _remoteConfigChannelIds.addAll(channelIds);
  }

  @override
  Future<void> reloadCache() async {
    log.info('Reloading cache for FeralFileDP1FeedService: $baseUrl');
    final playlists = await getAllPlaylists(usingCache: false);
    final channels = await getAllChannels(usingCache: false);
    cache.clearAll();
    cache
      ..insertListPlaylists(playlists.items)
      ..insertListChannels(channels.items);
  }

  @override
  void clearCache() {
    super.clearCache();
    // _remoteConfigChannelIds.clear();
  }
}
