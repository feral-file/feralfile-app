import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/services/dp1_to_drift_ingest_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart'
    as model;
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

/// Base implementation of DP1 feed service containing common playlist and item methods
class BaseDP1FeedServiceImpl extends BaseDP1FeedService {
  BaseDP1FeedServiceImpl({
    required super.baseUrl,
    this.isExternalFeedService = false,
  });

  @override
  final bool isExternalFeedService;

  late final DP1FeedApi api;
  late final DP1ToDriftIngestService ingestService;
  late final PlaylistDatabase db;

  /// Initialize api and Drift services - can be overridden by subclasses
  Future<void> init({
    FutureOr<void> Function(Object)? onPlaylistError,
    FutureOr<void> Function(Object)? onChannelError,
    Dio? dio,
  }) async {
    api = DP1FeedApi.dioBaseUrl(
      baseUrl: baseUrl,
      dio: dio,
    );
    db = injector<PlaylistDatabase>();
    final indexerService = injector<NftIndexerService>();
    ingestService = DP1ToDriftIngestService(db, indexerService);
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
    try {
      final created = await api.createPlaylist(request.toJson());
      if (isSyncToCloud) {
        final cloud = injector<AppDataManager>().dp1FeedStorageService;
        await cloud.insertPlaylists([created]);
      }
      return created;
    } catch (e) {
      // Keep API success even if cloud sync fails
      log.info('Failed to cache created DP1 playlist to cloud: $e');
      rethrow;
    }
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
      final cachedPlaylist = await db.getPlaylistById(playlistId);
      if (cachedPlaylist != null) {
        // Convert Drift row to DP1Call model
        return playlistRowToModel(cachedPlaylist);
      }
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
    await ingestService.ingestPlaylists(resp.items, baseUrl, null);
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
    // Drift query is async, so return empty for now
    // Call sites should use async methods instead
    log.info('[BaseDP1FeedServiceImpl] getAllCachedPlaylists - deprecated, use async methods');
    return [];
  }

  @override
  Future<bool> deletePlaylist(String id) async {
    await api.deletePlaylist(id);
    // Delete playlist from Drift
    await (db.delete(db.playlists)..where((p) => p.id.equals(id))).go();
    // Also delete associated entries
    await db.deletePlaylistEntries(id);
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

  bool _isReloadingCache = false;

  Future<void> reloadCache() async {
    if (_isReloadingCache) return;
    _isReloadingCache = true;
    try {
      bool hasMore = true;
      String? cursor;
      const limit = 50;
      // Note: Drift clears per-channel, not globally
      while (hasMore) {
        final resp = await api.getAllPlaylists(cursor: cursor, limit: limit);
        await ingestService.ingestPlaylists(resp.items, baseUrl, null);
        hasMore = resp.hasMore;
        cursor = resp.cursor;
      }
    } finally {
      _isReloadingCache = false;
    }
  }

  Future<void> clearCache() async {
    // Clear all Drift data
    await db.clearAll();
  }

  /// Convert Drift Playlist row to DP1Call model
  DP1Call playlistRowToModel(Playlist row) {
    // Parse signatures JSON array
    final signature = row.signaturesJson.isNotEmpty ? 'stored' : '';

    return DP1Call(
      dpVersion: row.dpVersion ?? '1.0.0',
      id: row.id,
      slug: row.slug ?? '',
      title: row.title,
      created: DateTime.fromMicrosecondsSinceEpoch(row.createdAtUs),
      defaults: null, // Parse from defaultsJson if needed
      items: const [], // Items loaded separately
      signature: signature,
      dynamicQueries: const [], // Parse from dynamicQueriesJson if needed
    );
  }

  /// Convert Drift Channel row to model.Channel
  model.Channel channelRowToModel(Channel row) {
    return model.Channel(
      id: row.id,
      slug: row.slug ?? '',
      title: row.title,
      curator: row.curator,
      summary: row.summary,
      playlists: const [], // Loaded separately
      created: DateTime.fromMicrosecondsSinceEpoch(row.createdAtUs),
      coverImage: row.coverImageUri,
    );
  }

  /*
  =======================================================================

  SERVICE CONFIGURATION

  =======================================================================
   */

  /// Get the feed service name mapping from remote config
  /// Returns a map of {url: name}
  Map<String, String> getServiceUrlToNameMap() {
    return injector<RemoteConfigService>().getConfig(
      ConfigGroup.dp1Playlist,
      ConfigKey.dp1FeedServerUrlToName,
      {},
      parser: (dynamic value) {
        return Map<String, String>.from(value as Map);
      },
    );
  }

  /// Get the service name for this feed service
  String? get name {
    return getServiceUrlToNameMap()[baseUrl];
  }
}
