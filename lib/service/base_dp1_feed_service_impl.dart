import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart'
    as model;
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/service/base_dp1_feed_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
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
  late final PlaylistDatabase db;
  late final DriftDatabaseService driftDb;
  late final ConfigurationService _configurationService;
  late final RemoteConfigService _remoteConfigService;

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
    driftDb = injector<DriftDatabaseService>();
    _configurationService = injector<ConfigurationService>();
    _remoteConfigService = injector<RemoteConfigService>();
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
      final cachedPlaylist = await driftDb.getPlaylistRowAsDp1Call(playlistId);
      return cachedPlaylist;
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
    final playlistRefs = resp.items
        .map(
          (p) => PlaylistReference(
            playlist: p,
            url: baseUrl,
          ),
        )
        .toList();
    await driftDb.ingestPlaylists(playlistRefs, null);
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
      final playlistRefs = resp.items
          .map(
            (p) => PlaylistReference(
              playlist: p,
              url: baseUrl,
            ),
          )
          .toList();
      await driftDb.ingestPlaylists(playlistRefs, null);
      hasMore = resp.hasMore;
      cursor = resp.cursor;
    }
    return playlists;
  }

  @override
  Future<List<DP1Call>> getAllCachedPlaylists() async {
    // Fetch cached DP1 playlists for this feed service from Drift.
    final playlists = await driftDb.getPlaylistRowsAsDp1Calls(
      kind: DriftPlaylistKind.dp1,
      baseUrl: baseUrl,
    );
    return playlists;
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

  /// Low-level cache reload that always re-ingests data for this feed service.
  ///
  /// Callers should normally use [reloadCacheIfNeeded] so that each service
  /// can respect its own cache policy and last-refresh time.
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
        final refs = resp.items
            .map(
              (p) => PlaylistReference(
                playlist: p,
                url: baseUrl,
              ),
            )
            .toList();
        await driftDb.ingestPlaylists(refs, null);
        hasMore = resp.hasMore;
        cursor = resp.cursor;
      }
    } finally {
      _isReloadingCache = false;
    }
  }

  Future<void> clearCache() async {
    // Delete last refresh time for this feed service
    await _configurationService.deleteDp1LastTimeRefreshFeedByUrl(baseUrl);
    // Clear all Drift data
    await driftDb.deleteAllPlaylists(
        kind: DriftPlaylistKind.dp1, baseUrl: baseUrl);
  }

  /// Get this service's last successful cache refresh time, based on baseUrl.
  DateTime? _getServiceLastRefreshTime() {
    final allByUrl = _configurationService.getDp1LastTimeRefreshFeedsByUrl();
    return allByUrl[baseUrl];
  }

  /// Persist this service's last successful cache refresh time.
  Future<void> _setServiceLastRefreshTime(DateTime time) async {
    final allByUrl = _configurationService.getDp1LastTimeRefreshFeedsByUrl();
    allByUrl[baseUrl] = time;
    await _configurationService.setDp1LastTimeRefreshFeedsByUrl(allByUrl);
  }

  /// Decide whether this feed service should reload its cache.
  ///
  /// Uses the same remote-config driven policy as the legacy FeedManager:
  /// - [ConfigKey.dp1FeedCacheDuration]: max allowed cache age in seconds
  /// - [ConfigKey.dp1FeedLastUpdated]: global content last-updated timestamp
  ///
  /// Each service compares these values against its own last-refresh time.
  Future<bool> shouldReloadCache() async {
    final lastServiceRefresh =
        _getServiceLastRefreshTime() ?? DateTime(1970, 1, 1);

    final updateFeedDurationString = _remoteConfigService.getConfig<String>(
      ConfigGroup.dp1Playlist,
      ConfigKey.dp1FeedCacheDuration,
      const Duration(days: 1).inSeconds.toString(),
    );
    final updateFeedDuration =
        Duration(seconds: int.parse(updateFeedDurationString));

    final lastFeedUpdateAtString = _remoteConfigService.getConfig<String>(
      ConfigGroup.dp1Playlist,
      ConfigKey.dp1FeedLastUpdated,
      DateTime(2023, 1, 1).toIso8601String(),
    );
    final lastFeedUpdateAt = DateTime.parse(lastFeedUpdateAtString);

    final now = DateTime.now();
    final isStaleByAge =
        lastServiceRefresh.isBefore(now.subtract(updateFeedDuration));
    final isOutdatedByRemoteUpdate = lastFeedUpdateAt.isAfter(
      lastServiceRefresh,
    );

    final shouldUpdate = isStaleByAge || isOutdatedByRemoteUpdate;

    log.info(
      '[BaseDP1FeedServiceImpl] shouldReloadCache '
      'baseUrl=$baseUrl, shouldUpdate=$shouldUpdate, '
      'lastServiceRefresh=$lastServiceRefresh, '
      'updateFeedDuration=$updateFeedDuration, '
      'lastFeedUpdateAt=$lastFeedUpdateAt',
    );

    return shouldUpdate;
  }

  /// Public entry point for callers that want this service to ensure its cache
  /// is up to date.
  ///
  /// When [force] is true, the cache is always reloaded regardless of policy.
  /// Otherwise, [shouldReloadCache] is evaluated and the reload is skipped
  /// when not needed.
  Future<void> reloadCacheIfNeeded({bool force = false}) async {
    if (force) {
      log.info(
        '[BaseDP1FeedServiceImpl] Forced cache reload for baseUrl=$baseUrl',
      );
      await reloadCache();
      await _setServiceLastRefreshTime(DateTime.now());
      return;
    }

    final shouldUpdate = await shouldReloadCache();
    if (!shouldUpdate) {
      log.info(
        '[BaseDP1FeedServiceImpl] Skip cache reload for baseUrl=$baseUrl '
        '(up to date)',
      );
      return;
    }

    log.info(
      '[BaseDP1FeedServiceImpl] Reloading cache (policy) for baseUrl=$baseUrl',
    );
    await reloadCache();
    await _setServiceLastRefreshTime(DateTime.now());
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
