import 'dart:async';

import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as drift_db;
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service_impl.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
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
  DP1FeedWithChannelExtensionServiceBase(
      {required super.baseUrl, this.isExternalFeedService = false});

  final bool isExternalFeedService;

  /*
  =======================================================================

  PLAYLIST

  =======================================================================
  */

  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
  });

  List<DP1Call> getCachedPlaylistsByChannelId(String channelId);

  Future<DP1PlaylistResponse> getAllPlaylistsByChannelIds({
    required List<String> channelIds,
    String? cursor,
    int? limit,
  });

  /*
  =======================================================================

  CHANNEL

  =======================================================================
  */

  Channel? getChannelByPlaylistId(String playlistId);

  Future<Channel?> getChannelDetail(String channelId, {bool fromCache = true});

  Future<List<Channel>> getChannelsByIds({
    required List<String> channelIds,
    bool usingCache = true,
  });

  Future<DP1ChannelsResponse> getChannels({
    String? cursor,
    int? limit,
  });

  Future<List<Channel>> getAllChannels();

  List<Channel> getAllCachedChannels();

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

class DP1FeedWithChannelExtensionServiceImpl extends BaseDP1FeedServiceImpl
    implements DP1FeedWithChannelExtensionServiceBase {
  DP1FeedWithChannelExtensionServiceImpl({required super.baseUrl});

  @override
  Future<void> init({
    FutureOr<void> Function(Object)? onPlaylistError,
    FutureOr<void> Function(Object)? onChannelError,
    Dio? dio,
  }) async {
    // Pass custom dio to parent init
    await super.init(
      onPlaylistError: onPlaylistError,
      onChannelError: onChannelError,
      dio: dio ??
          DioManager().dp1Feed(
            BaseOptions(
              followRedirects: true,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ),
    );
  }

  /*  
  =======================================================================

  PLAYLIST

  =======================================================================
  */

  @override
  Future<DP1PlaylistResponse> getPlaylistsByChannelId({
    required String channelId,
    String? cursor,
    int? limit,
  }) async {
    final resp = await api.getAllPlaylists(
      channelId: channelId,
      cursor: cursor,
      limit: limit,
    );
    return resp;
  }

  @override
  List<DP1Call> getCachedPlaylistsByChannelId(String channelId) {
    // Drift is async, deprecated sync method
    log.info('[DP1FeedService] getCachedPlaylistsByChannelId - use async methods');
    return [];
  }

  @override
  Future<DP1PlaylistResponse> getAllPlaylistsByChannelIds({
    required List<String> channelIds,
    String? cursor,
    int? limit,
  }) async {
    if (channelIds.isEmpty) {
      return DP1PlaylistResponse([], false, null);
    }

    // Parse composite cursor: "channelIndex:innerCursor"
    int currentChannelIndex = 0;
    String? currentChannelCursor = cursor;
    if (cursor != null && cursor.contains(':')) {
      final parts = cursor.split(':');
      if (parts.length == 2) {
        currentChannelIndex = int.tryParse(parts[0]) ?? 0;
        currentChannelCursor = parts[1].isEmpty ? null : parts[1];
      }
    }

    // Clamp to valid range
    currentChannelIndex = currentChannelIndex.clamp(0, channelIds.length - 1);

    final List<DP1Call> allItems = [];
    bool hasMore = false;
    String? nextCursor;

    for (int i = currentChannelIndex; i < channelIds.length; i++) {
      final channelId = channelIds[i];
      try {
        final remainingLimit = limit != null ? limit - allItems.length : limit;
        final response = await getPlaylistsByChannelId(
          channelId: channelId,
          cursor: (i == currentChannelIndex) ? currentChannelCursor : null,
          limit: remainingLimit,
        );

        allItems.addAll(response.items);

        // If we've reached the requested limit, prepare next cursor
        if (limit != null && allItems.length >= limit) {
          if (response.hasMore) {
            hasMore = true;
            nextCursor = '${i}:${response.cursor ?? ''}';
          } else if (i < channelIds.length - 1) {
            hasMore = true;
            nextCursor = '${i + 1}:';
          }
          break;
        }

        if (response.hasMore) {
          hasMore = true;
          nextCursor = '${i}:${response.cursor ?? ''}';
          break;
        } else if (i < channelIds.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      } catch (e) {
        log.info('Error getting playlists for channel $channelId: $e');
        if (i < channelIds.length - 1) {
          hasMore = true;
          nextCursor = '${i + 1}:';
        }
      }
    }

    return DP1PlaylistResponse(allItems, hasMore, nextCursor);
  }

  /*
  =======================================================================

  CHANNEL

  =======================================================================
  */

  @override
  Channel? getChannelByPlaylistId(String playlistId) {
    // Drift is async, deprecated sync method
    log.info('[DP1FeedService] getChannelByPlaylistId - use async methods');
    return null;
  }

  @override
  Future<Channel?> getChannelDetail(
    String channelId, {
    bool fromCache = true,
  }) async {
    if (fromCache) {
      final cached = await db.getChannelById(channelId);
      if (cached != null) {
        return channelRowToModel(cached);
      }
      return null;
    }
    final channel = await api.getChannelById(channelId);
    return channel;
  }

  @override
  Future<List<Channel>> getChannelsByIds({
    required List<String> channelIds,
    bool usingCache = true,
  }) async {
    const batchSize = 10;
    if (!usingCache) {
      log.info('Fetching channels by IDs from API, not using cache');
    }

    final channels = <Channel>[];
    for (final batch in channelIds.batch(batchSize)) {
      final futures = batch.map((id) async {
        return getChannelDetail(id, fromCache: usingCache);
      }).toList();
      final results = await Future.wait(futures);
      channels.addAll(results.nonNulls.toList());
    }
    return channels.nonNulls.toList();
  }

  @override
  Future<DP1ChannelsResponse> getChannels({
    String? cursor,
    int? limit,
  }) async {
    String? currentCursor = cursor;
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

    await ingestService.ingestChannels(channels.items, baseUrl);

    return DP1ChannelsResponse(
      channels.items,
      channels.hasMore,
      channels.cursor,
    );
  }

  @override
  Future<List<Channel>> getAllChannels() async {
    final channels = <Channel>[];
    bool hasMore = true;
    String? cursor = null;
    int? limit = 10;
    while (hasMore) {
      final resp = await api.getAllChannels(cursor: cursor, limit: limit);
      channels.addAll(resp.items);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
    return channels;
  }

  @override
  List<Channel> getAllCachedChannels() {
    // Drift is async, deprecated sync method
    log.info('[DP1FeedService] getAllCachedChannels - use async methods');
    return [];
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

  bool _isReloadingCache = false;

  @override
  Future<void> reloadCache() async {
    if (_isReloadingCache) return;
    _isReloadingCache = true;
    try {
      log.info('Reloading cache for FeralFileDP1FeedService: $baseUrl');
      final channels = await getAllChannels();
      final playlists = await getAllPlaylists();
      await db.clearAll();
      await ingestService.ingestChannels(channels, baseUrl);
      await ingestService.ingestPlaylists(playlists, baseUrl, null);
      _isReloadingCache = false;
    } catch (e) {
      log.info('Failed to reload cache for FeralFileDP1FeedService: $e');
      _isReloadingCache = false;
      rethrow;
    }
  }

  @override
  Future<void> clearCache() async {
    await super.clearCache();
  }
}

class FeralFileDP1FeedService extends DP1FeedWithChannelExtensionServiceImpl {
  FeralFileDP1FeedService({required super.baseUrl}) : super();

  final List<String> _remoteConfigChannelIds = [];

  void addRemoteConfigChannelIds(List<String> channelIds) {
    _remoteConfigChannelIds.addAll(channelIds);
  }

  /*
  =======================================================================

  PLAYLIST

  =======================================================================
  */

  @override
  Future<List<DP1Call>> getAllPlaylists() async {
    if (_remoteConfigChannelIds.isNotEmpty) {
      final playlists = <DP1Call>[];
      bool hasMore = true;
      String? cursor = null;
      int? limit = 20;
      while (hasMore) {
        final response = await getAllPlaylistsByChannelIds(
          channelIds: _remoteConfigChannelIds,
          cursor: cursor,
          limit: limit,
        );
        playlists.addAll(response.items);
        hasMore = response.hasMore;
        cursor = response.cursor;
      }

      return playlists;
    } else {
      final res = await super.getAllPlaylists();
      return res;
    }
  }

  /*
  =======================================================================

  CHANNEL

  =======================================================================
  */

  @override
  Future<List<Channel>> getAllChannels() async {
    if (_remoteConfigChannelIds.isNotEmpty) {
      final channels = await getChannelsByIds(
        channelIds: _remoteConfigChannelIds,
        usingCache: false,
      );
      return channels;
    } else {
      final res = await super.getAllChannels();
      return res;
    }
  }

  @override
  List<DP1Call> getAllCachedPlaylists() {
    // Drift is async, deprecated sync method
    log.info('[DP1FeedService] getAllCachedPlaylists - use async methods');
    return [];
  }

  @override
  List<Channel> getAllCachedChannels() {
    // Drift is async, deprecated sync method
    log.info('[DP1FeedService] getAllCachedChannels - use async methods');
    return [];
  }
}
