import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

class RemoteConfigChannel {
  final String endpoint;
  final String channelId;

  RemoteConfigChannel({
    required this.endpoint,
    required this.channelId,
  });

  String get url => '$endpoint/api/v1/channels/$channelId';
}

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
    required RemoteConfigChannel channel,
    String? cursor,
    int? limit,
    bool usingCache = true,
  });

  Future<DP1PlaylistItemsResponse> getPlaylistItemsByListOfChannels({
    required List<RemoteConfigChannel> channels,
    String? cursor,
    int? limit,
    bool usingCache = true,
  });
}

class FeralFileDP1FeedService extends BaseDP1FeedServiceImpl
    implements FeralFileDP1FeedServiceBase {
  FeralFileDP1FeedService(super.api, super.feedCacheManager) : super();

  @override
  List<String>? get remoteConfigChannelIds =>
      remoteConfigChannels?.map((channel) => channel.channelId).toList();

  List<String>? get _remoteConfigChannelUrls => [
        // 'https://dp1-feed-operator-api-prod.autonomy-system.workers.dev/api/v1/channels/dae709d7-26da-4b4c-b881-39cd681cc82f',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/cb3455c2-7122-4414-a9f5-7ccbe434de21',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/5b467722-202d-44d2-af77-4c438c7f2258',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/21f9b1a1-7ad6-4752-ba2c-3f675c4dea63',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/92c75624-10ee-403b-81eb-0da0011d4dde',
        'https://dp1-feed-operator-api-dev.objkt-com.workers.dev/api/v1/channels/70930b59-04cc-49e0-a982-7ffc17210add',
      ];

  List<RemoteConfigChannel>? get remoteConfigChannels =>
      _remoteConfigChannelUrls?.map((url) {
        final uri = Uri.parse(url);
        // enpoint: https://dp1-feed-operator-api-prod.autonomy-system.workers.dev
        // channelId: dae709d7-26da-4b4c-b881-39cd681cc82f
        return RemoteConfigChannel(
          endpoint: uri.origin,
          channelId: uri.pathSegments.last,
        );
      }).toList();

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

    if (remoteConfigChannels != null) {
      final channels = (await getChannelsByUrls(
              channelUrls: remoteConfigChannels!.map((c) => c.url).toList(),
              usingCache: usingCache))
          .values
          .toList();
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
  Future<Map<String, Channel>> getChannelsByUrls({
    required List<String> channelUrls,
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedChannels = feedCacheManager.getChannelsByUrls(channelUrls);
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
          feedCacheManager.setChannels([channel]);
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
    if (remoteConfigChannels != null) {
      final channels = await getChannelsByUrls(
          channelUrls: remoteConfigChannels!.map((c) => c.url).toList(),
          usingCache: usingCache);
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
        (channel) =>
            !(remoteConfigChannels?.any((c) => c.channelId == channel.id) ??
                true),
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
    required RemoteConfigChannel channel,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    final api = DP1FeedApi.dioBaseUrl(baseUrl: channel.endpoint);
    final channelId = channel.channelId;
    return api.getPlaylistItems(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<DP1PlaylistItemsResponse> getPlaylistItemsByListOfChannels({
    required List<RemoteConfigChannel> channels,
    String? cursor,
    int? limit,
    bool usingCache = true,
  }) async {
    if (channels.isEmpty) {
      return DP1PlaylistItemsResponse([], false, null);
    }

    // Parse cursor to get current channel index and channel cursor
    int currentChannelIndex = 0;
    String? currentChannelCursor = cursor;

    if (cursor != null && cursor.contains(':')) {
      final parts = cursor.split(':');
      if (parts.length == 2) {
        currentChannelIndex = int.tryParse(parts[0]) ?? 0;
        currentChannelCursor = parts[1].isEmpty ? null : parts[1];
      }
    }

    // Ensure index is within bounds
    currentChannelIndex = currentChannelIndex.clamp(0, channels.length - 1);

    final List<DP1Item> allItems = [];
    bool hasMore = false;
    String? nextCursor;

    // Start from current channel index
    for (int i = currentChannelIndex; i < channels.length; i++) {
      final channel = channels[i];
      try {
        // Calculate remaining limit for this channel
        final remainingLimit = limit != null ? limit - allItems.length : limit;

        final response = await getPlaylistItemsOfChannel(
          channel: channel,
          cursor: (i == currentChannelIndex) ? currentChannelCursor : null,
          limit: remainingLimit,
          usingCache: usingCache,
        );

        allItems.addAll(response.items);

        // Check if we've reached the limit after adding items
        if (limit != null && allItems.length >= limit) {
          if (response.hasMore) {
            // Current channel has more items, continue with this channel
            hasMore = true;
            nextCursor = '${i}:${response.cursor ?? ''}';
          } else if (i < channels.length - 1) {
            // Current channel is exhausted but there are more channels
            hasMore = true;
            nextCursor = '${i + 1}:';
          }
          break;
        }

        if (response.hasMore) {
          // If current channel has more items, continue with this channel
          hasMore = true;
          nextCursor = '${i}:${response.cursor ?? ''}';
          break;
        } else if (i < channels.length - 1) {
          // If current channel is exhausted but there are more channels, continue to next
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      } catch (e) {
        log.info(
            'Error getting playlist items for channel ${channel.channelId}: $e');
        // Continue to next channel on error
        if (i < channels.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      }
    }

    return DP1PlaylistItemsResponse(
      allItems,
      hasMore,
      nextCursor,
    );
  }
}
