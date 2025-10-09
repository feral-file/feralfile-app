import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/util/feed_cache.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:meta/meta.dart';

/// Base implementation of DP1 feed service containing common playlist and item methods
class BaseDP1FeedServiceImpl extends BaseDP1FeedService {
  BaseDP1FeedServiceImpl({required String baseUrl}) : super(baseUrl: baseUrl) {
    initializeApiAndCache(baseUrl);
  }

  late final DP1FeedApi api;
  late final BaseFeedCache cache;

  /// Initialize api and cache - can be overridden by subclasses
  @protected
  void initializeApiAndCache(String baseUrl) {
    api = DP1FeedApi.dioBaseUrl(baseUrl: baseUrl);
    cache = FeedCacheImpl(baseUrl: baseUrl);
  }

  /*
  =======================================================================

  PLAYLIST
  Base implementation for playlist methods
  
  =======================================================================
  */

  // create playlist
  @override
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
  @override
  Future<DP1Call> updatePlaylist(
      {required String playlistId,
      required DP1CreatePlaylistRequest request,
      bool isSyncToCloud = true}) async {
    final updatedPlaylist =
        await api.updatePlaylist(playlistId, request.toJson());
    return updatedPlaylist;
  }

  // get playlist by id
  @override
  Future<DP1Call> getPlaylistById(String playlistId,
      {bool usingCache = true}) async {
    if (usingCache) {
      final cachedPlaylist = cache.getPlaylistById(playlistId);
      if (cachedPlaylist != null) return cachedPlaylist;
    }
    final result = await api.getPlaylistById(playlistId);
    return result;
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

    final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
    cache.insertListPlaylists(resp.items);
    return resp;
  }

  @override
  Future<bool> deletePlaylist(String id) async {
    await api.deletePlaylist(id);
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
    bool usingCache = true,
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
    final playlists = await getAllPlaylists(usingCache: false);
    log.info('Reloaded cache:${playlists.items.length} playlists');
    cache
      ..clearAll()
      ..insertListPlaylists(playlists.items);
  }

  void clearCache() {
    cache.clearAll();
  }
}
