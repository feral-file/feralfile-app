import 'dart:async';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/error/dp1_error.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry/sentry.dart';
import 'package:uuid/uuid.dart';

/// A high-level service to manage a user's DP1 playlists.
///
/// This service coordinates between the remote DP1 feed API (via DP1FeedService)
/// and local cloud storage (via CloudManager.dp1FeedCloudObject).
class UserDp1PlaylistService {
  UserDp1PlaylistService(this._dp1FeedService, this._cloudManager);

  final FeralFileDP1FeedService _dp1FeedService;
  final CloudManager _cloudManager;

  DP1Call? _cachedAllOwnedPlaylist;

  // make sure the cached playlist is not null
  DP1Call get cachedAllOwnedPlaylist {
    if (_cachedAllOwnedPlaylist == null) {
      Sentry.captureMessage('Cached all owned playlist is null when accessed');
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    return _cachedAllOwnedPlaylist!;
  }

  void set cachedAllOwnedPlaylist(DP1Call? playlist) {
    _cachedAllOwnedPlaylist = playlist;
    final dynamicQuery = playlist?.firstDynamicQuery;
    if (dynamicQuery == null) {
      return;
    }
    final bloc = injector<UserAllOwnCollectionBloc>();
    bloc.add(UpdateDynamicQueryEvent(dynamicQuery: dynamicQuery));
  }

  Future<DP1Call> allOwnedPlaylist() async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isEmpty) {
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    final playlistId = allOwnedPlaylistIds.first;
    final playlist = await _dp1FeedService.getPlaylistById(playlistId);
    if (playlist == null) {
      unawaited(Sentry.captureMessage(
          '[User Playlist Service] [allOwnedPlaylist] All owned playlist not found in DP1 service, id: $playlistId'));
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    return playlist;
  }

  /// Create a new playlist remotely and cache it locally under owned playlists.
  Future<DP1Call> createAllOwnedPlaylistIfNotExists() async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isNotEmpty) {
      final playlistId = allOwnedPlaylistIds.first;
      DP1Call? playlist =
          await _dp1FeedService.getPlaylistById(playlistId, usingCache: false);
      if (playlist != null) {
        // migrate from old indexer to new indexer
        final newIndexerUrl = '${Environment.indexerURL}/graphql';
        if (playlist.dynamicQueries.any((e) => e.endpoint != newIndexerUrl)) {
          final newPlaylist = playlist.copyWith(
            dynamicQueries: playlist.dynamicQueries
                .map((e) => e.copyWith(endpoint: newIndexerUrl))
                .toList(),
          );
          final updatePlaylistRequest =
              DP1CreatePlaylistRequest.fromDP1Call(newPlaylist);
          playlist = await _dp1FeedService.updatePlaylist(
            playlistId: playlistId,
            request: updatePlaylistRequest,
          );
        }
        cachedAllOwnedPlaylist = playlist;
        return playlist;
      } else {
        unawaited(Sentry.captureMessage(
            '[createAllOwnedPlaylistIfNotExists] All owned playlist not found in DP1 service, id: $playlistId'));
        // If the playlist ID exists in cloud but not found in DP1 service, remove it from cloud
        _cloudManager.dp1FeedCloudObject.removeOwnedPlaylistId(playlistId);
      }
    }

    final allOwnedAddresses = await _cloudManager.addressObject
        .getAllAddresses()
        .where((e) => !e.isHidden);
    final title = 'All Own ${const Uuid().v1()}';
    final request = DP1CreatePlaylistRequest(
      dpVersion: '1.0.0',
      title: title,
      items: [],
      dynamicQueries: [
        DynamicQuery(
          endpoint: '${Environment.indexerURL}/graphql',
          params: DynamicQueryParams(
              owners: allOwnedAddresses.map((e) => e.address).toList()),
        )
      ],
    );

    final created = await _dp1FeedService.createPlaylist(
      request: request,
      isSyncToCloud: true,
    );

    await _cloudManager.dp1FeedCloudObject.addOwnedPlaylistId(created.id);
    cachedAllOwnedPlaylist = created;
    return created;
  }

  Future<DP1Call?> getPlaylistById(String id) async {
    final playlist = _dp1FeedService.getPlaylistById(id);
    return playlist;
  }

  Future<DP1Call> insertAddressesToPlaylist(List<String> addresses) async {
    log.info('Insert addresses to playlist: $addresses');
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isEmpty) {
      log.info('All owned playlist is empty');
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    final playlistId = allOwnedPlaylistIds.first;
    final currentPlaylist = await _dp1FeedService.getPlaylistById(playlistId);
    if (currentPlaylist == null) {
      log.info(
          '[insertAddressesToPlaylist] All owned playlist not found in DP1 service, id: $playlistId');
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    final request = DP1CreatePlaylistRequest(
      dpVersion: currentPlaylist.dpVersion,
      title: currentPlaylist.title,
      items: currentPlaylist.items,
      dynamicQueries: currentPlaylist.dynamicQueries
          .map((e) => e.insertAddresses(addresses))
          .toList(),
    );

    final playlist = await _dp1FeedService.updatePlaylist(
        playlistId: playlistId, request: request);
    cachedAllOwnedPlaylist = playlist;
    log.info('Inserted addresses to playlist: $addresses');
    return playlist;
  }

  Future<DP1Call> removeAddressesFromPlaylist(List<String> addresses) async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isEmpty) {
      log.info('All owned playlist is empty');
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    final playlistId = allOwnedPlaylistIds.first;
    final currentPlaylist = await _dp1FeedService.getPlaylistById(playlistId);
    if (currentPlaylist == null) {
      log.info(
          '[removeAddressesFromPlaylist] All owned playlist not found in DP1 service, id: $playlistId');
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    final request = DP1CreatePlaylistRequest(
      dpVersion: currentPlaylist.dpVersion,
      title: currentPlaylist.title,
      items: currentPlaylist.items,
      dynamicQueries: currentPlaylist.dynamicQueries
          .map((e) => e.removeAddresses(addresses))
          .toList(),
    );

    final playlist = await _dp1FeedService.updatePlaylist(
        playlistId: playlistId, request: request);
    cachedAllOwnedPlaylist = playlist;
    final map = addresses.map((e) => MapEntry(e, null));
    await updateAddressLastIndexTime(addresses: Map.fromEntries(map));
    await updateAddressLastFetchTokenTime(addresses: Map.fromEntries(map));

    log.info('Removed addresses from playlist: $addresses');
    return playlist;
  }

  Future<bool> deleteAllPlaylists() async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isEmpty) {
      log.info('All owned playlists are empty');
      return true;
    }
    final deleted = await Future.wait(allOwnedPlaylistIds.map(deletePlaylist));
    await injector<ConfigurationService>().setAddressLastIndexTime({});

    if (deleted.any((e) => e == false)) {
      log.info('Failed to delete all owned playlists');
      return false;
    }
    return true;
  }

  Future<bool> deletePlaylist(String id) async {
    try {
      log.info('Delete playlist: $id');
      final deleted = _dp1FeedService.deletePlaylist(id);
      _cloudManager.dp1FeedCloudObject.removeOwnedPlaylistId(id);
      log.info('Deleted playlist: $id');
      return deleted;
    } catch (e) {
      log.info('Failed to delete playlist: $e');
      return false;
    }
  }

  Future<void> updateAddressLastIndexTime({
    required Map<String, DateTime?> addresses,
  }) async {
    final addressLastRefreshedTime =
        injector<ConfigurationService>().getAddressLastIndexTime();
    // update the time for the addresses
    for (final entry in addresses.entries) {
      if (entry.value == null) {
        addressLastRefreshedTime.remove(entry.key);
      } else {
        final candidate = entry.value!.toUtc();
        final current = addressLastRefreshedTime[entry.key];
        if (current == null || candidate.isAfter(current)) {
          addressLastRefreshedTime[entry.key] = candidate;
        } else {
          addressLastRefreshedTime[entry.key] = current;
        }
      }
    }
    await injector<ConfigurationService>()
        .setAddressLastIndexTime(addressLastRefreshedTime);
  }

  Map<String, DateTime?> getAddressOldestLastIndexTime({
    required List<String> addresses,
  }) {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    final result = <String, DateTime?>{};
    for (final addr in addresses) {
      result[addr] = map[addr];
    }
    return result;
  }

  bool isAddressIndexed(String address) {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    return map.containsKey(address);
  }

  Future<void> updateAddressLastFetchTokenTime({
    required Map<String, DateTime?> addresses,
  }) async {
    final addressLastFetchTokenTime =
        injector<ConfigurationService>().getAddressLastFetchTokenTime();
    // update the time for the addresses
    for (final entry in addresses.entries) {
      if (entry.value == null) {
        addressLastFetchTokenTime.remove(entry.key);
      } else {
        final candidate = entry.value!.toUtc();
        final current = addressLastFetchTokenTime[entry.key];
        if (current == null || candidate.isAfter(current)) {
          addressLastFetchTokenTime[entry.key] = candidate;
        } else {
          addressLastFetchTokenTime[entry.key] = current;
        }
      }
    }
    await injector<ConfigurationService>()
        .setAddressLastFetchTokenTime(addressLastFetchTokenTime);
  }

  Map<String, DateTime?> getAddressOldestLastFetchTokenTime({
    required List<String> addresses,
  }) {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    final result = <String, DateTime?>{};
    for (final addr in addresses) {
      result[addr] = map[addr];
    }
    return result;
  }

  bool isAddressFetched(String address) {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    return map.containsKey(address);
  }

  Future<void> clearData() async {
    // await injector<ConfigurationService>().clearAddressLastRefreshedTime();
    cachedAllOwnedPlaylist = null;
  }
}
