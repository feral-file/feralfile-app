import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/util/feed_cache.dart';
import 'package:autonomy_flutter/util/log.dart';

/// Base implementation of DP1 feed service containing common playlist and item methods
class BaseDP1FeedServiceImpl extends BaseDP1FeedService {
  BaseDP1FeedServiceImpl({required String baseUrl}) : super(baseUrl: baseUrl) {}

  late final DP1FeedApi api;
  late final BaseFeedCache cache;

  /// Initialize api and cache - can be overridden by subclasses
  Future<void> init() async {
    api = DP1FeedApi.dioBaseUrl(baseUrl: baseUrl);
    cache = FeedCacheImpl(baseUrl: baseUrl);
    await cache.init();
  }

  /*
  =======================================================================

  PLAYLIST
  Base implementation for playlist methods
  
  =======================================================================
  */

  // create playlist
  @override
  Future<DP1Call> createPlaylist({
    required DP1CreatePlaylistRequest request,
    bool isSyncToCloud = true,
  }) async {
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
  @override
  Future<DP1Call> updatePlaylist({
    required String playlistId,
    required DP1CreatePlaylistRequest request,
    bool isSyncToCloud = true,
  }) async {
    final updatedPlaylist =
        await api.updatePlaylist(playlistId, request.toJson());
    return updatedPlaylist;
  }

  // get playlist by id
  @override
  Future<DP1Call?> getPlaylistById(
    String playlistId, {
    bool usingCache = true,
  }) async {
    if (usingCache) {
      final cachedPlaylist = cache.getPlaylistById(playlistId);
      if (cachedPlaylist != null) return cachedPlaylist;
    }
    try {
      final result = await api.getPlaylistById(playlistId);
      return result;
    } catch (e) {
      log.info('Error fetching playlist by ID $playlistId: $e');
      return null;
    }
  }

  @override
  Future<DP1PlaylistResponse> getPlaylists({
    String? cursor,
    int? limit,
  }) async {
    final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
    cache.insertListPlaylists(resp.items);
    return resp;
  }

  @override
  Future<List<DP1Call>> getAllPlaylists() async {
    final playlists = <DP1Call>[];
    var hasMore = true;
    String? cursor;
    const limit = 50;
    while (hasMore) {
      final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
      playlists.addAll(resp.items);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
    return playlists;
  }

  @override
  List<DP1Call> getAllCachedPlaylists() {
    return cache.getAllPlaylists();
  }

  @override
  Future<bool> deletePlaylist(String id) async {
    await api.deletePlaylist(id);
    cache.removePlaylistById(id);
    return true;
  }

  /*
  =======================================================================

  PLAYLIST ITEMS
  Base implementation for playlist item methods

  =======================================================================
  */

  @override
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
  }) async {
    return api.getPlaylistItems(
      cursor: cursor,
      limit: limit,
    );
  }

  /*
  =======================================================================

  CACHE

  =======================================================================
   */

  Future<void> reloadCache() async {
    bool hasMore = true;
    String? cursor;
    const limit = 50;
    cache.clearAll();
    while (hasMore) {
      final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
      cache.insertListPlaylists(resp.items);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
  }

  void clearCache() {
    cache.clearAll();
  }
}
