import 'dart:async';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/error/dp1_error.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
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
/// and local storage (via AppDataManager.dp1FeedStorageService).
class UserDp1PlaylistService {
  UserDp1PlaylistService(this._dp1FeedService, this._appDataManager);

  final FeralFileDP1FeedService _dp1FeedService;
  final AppDataManager _appDataManager;

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
        _appDataManager.dp1FeedStorageService.getOwnedPlaylistIds();
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
        _appDataManager.dp1FeedStorageService.getOwnedPlaylistIds();
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
        _appDataManager.dp1FeedStorageService.removeOwnedPlaylistId(playlistId);
      }
    }

    final allOwnedAddresses = _appDataManager.addressStorageService
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

    await _appDataManager.dp1FeedStorageService.addOwnedPlaylistId(created.id);
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
        _appDataManager.dp1FeedStorageService.getOwnedPlaylistIds();
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
        _appDataManager.dp1FeedStorageService.getOwnedPlaylistIds();
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
    await clearAddressLastIndexTime(addresses: addresses);
    await clearAddressLastFetchTokenTime(addresses: addresses);
    await removeLastUpdateChangeAnchor(addresses: addresses);

    log.info('Removed addresses from playlist: $addresses');
    return playlist;
  }

  Future<bool> deleteAllPlaylists() async {
    final allOwnedPlaylistIds =
        _appDataManager.dp1FeedStorageService.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isEmpty) {
      log.info('All owned playlists are empty');
      return true;
    }
    final deleted = await Future.wait(allOwnedPlaylistIds.map(deletePlaylist));
    await setAddressLastFetchTokenTime(addresses: {});
    await setAddressLastIndexTime(addresses: {});
    await setLastUpdateChangeAnchor(addressAnchors: []);

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
      await _appDataManager.dp1FeedStorageService.removeOwnedPlaylistId(id);
      log.info('Deleted playlist: $id');
      return deleted;
    } catch (e) {
      log.info('Failed to delete playlist: $e');
      return false;
    }
  }

  /*
  ------------------------------------------------------------
  ADDRESS LAST INDEX TIME
  ------------------------------------------------------------
  This is used to track the last index time for each address.
  */

  Future<void> setAddressLastIndexTime({
    required Map<String, DateTime> addresses,
  }) async {
    await injector<ConfigurationService>().setAddressLastIndexTime(addresses);
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
    await setAddressLastIndexTime(addresses: addressLastRefreshedTime);
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

  Future<void> clearAddressLastIndexTime({
    required List<String> addresses,
  }) async {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    for (final addr in addresses) {
      map.remove(addr);
    }
    await setAddressLastIndexTime(addresses: map);
  }

  bool isAddressIndexed(String address) {
    final map = injector<ConfigurationService>().getAddressLastIndexTime();
    return map.containsKey(address);
  }

  /*
  ------------------------------------------------------------
  ADDRESS LAST FETCH TOKEN TIME
  ------------------------------------------------------------
  This is used to track the last fetch token time for each address.
  */
  Future<void> setAddressLastFetchTokenTime({
    required Map<String, DateTime> addresses,
  }) async {
    await injector<ConfigurationService>()
        .setAddressLastFetchTokenTime(addresses);
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
    await setAddressLastFetchTokenTime(addresses: addressLastFetchTokenTime);
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

  Future<void> clearAddressLastFetchTokenTime({
    required List<String> addresses,
  }) async {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    for (final addr in addresses) {
      map.remove(addr);
    }
    await setAddressLastFetchTokenTime(addresses: map);
  }

  bool isAddressFetched(String address) {
    final map = injector<ConfigurationService>().getAddressLastFetchTokenTime();
    return map.containsKey(address);
  }

  /*
  ------------------------------------------------------------
  ADDRESS ANCHOR
  ------------------------------------------------------------
  This is used to track the last update change anchor for each address.
   */

  List<AddressAnchor> getLastUpdateChangeAnchor(
      {required List<String> addresses,
      AddressAnchor Function(String address)? defaultAnchorBuilder}) {
    return injector<ConfigurationService>().getLastUpdateChangeAnchor(
        addresses: addresses, defaultAnchorBuilder: defaultAnchorBuilder);
  }

  Future<void> setLastUpdateChangeAnchor(
      {required List<AddressAnchor> addressAnchors}) async {
    await injector<ConfigurationService>()
        .setLastUpdateChangeAnchor(addressAnchors: addressAnchors);
  }

  Future<void> updateLastUpdateChangeAnchor(
      {required List<AddressAnchor> addressAnchors}) async {
    final currentAnchor = getLastUpdateChangeAnchor(
        addresses: addressAnchors.map((e) => e.address).toList());
    for (final anchor in addressAnchors) {
      if (currentAnchor.any((e) => e.address == anchor.address)) {
        currentAnchor.removeWhere((e) => e.address == anchor.address);
      }
    }
    currentAnchor.addAll(addressAnchors);
    await injector<ConfigurationService>()
        .setLastUpdateChangeAnchor(addressAnchors: currentAnchor);
  }

  Future<void> removeLastUpdateChangeAnchor(
      {required List<String> addresses}) async {
    final currentAnchor = getLastUpdateChangeAnchor(addresses: addresses);
    currentAnchor.removeWhere((anchor) => addresses.contains(anchor.address));
    await setLastUpdateChangeAnchor(addressAnchors: currentAnchor);
  }

  Future<void> clearData() async {
    // await injector<ConfigurationService>().clearAddressLastRefreshedTime();
    cachedAllOwnedPlaylist = null;
    await setAddressLastIndexTime(addresses: {});
    await setAddressLastFetchTokenTime(addresses: {});
    await setLastUpdateChangeAnchor(addressAnchors: []);
  }
}
