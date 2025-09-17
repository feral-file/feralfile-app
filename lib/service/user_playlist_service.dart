import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/error/dp1_error.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry/sentry.dart';
import 'package:uuid/uuid.dart';

import 'dp1_feed_service.dart';

/// A high-level service to manage a user's DP1 playlists.
///
/// This service coordinates between the remote DP1 feed API (via DP1FeedService)
/// and local cloud storage (via CloudManager.dp1FeedCloudObject).
class UserDp1PlaylistService {
  UserDp1PlaylistService(this._dp1FeedService, this._cloudManager);

  final DP1FeedService _dp1FeedService;
  final CloudManager _cloudManager;

  Map<String, DateTime> addressLastRefreshedTime = {};

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

  Future<DP1Call> allOwnedPlaylist() async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isEmpty) {
      throw DP1AllOwnCollectionEmptyError(
          message: 'All owned playlist not found');
    }
    final playlistId = allOwnedPlaylistIds.first;
    final playlist = await _dp1FeedService.getPlaylistById(playlistId);
    return playlist;
  }

  /// Create a new playlist remotely and cache it locally under owned playlists.
  Future<DP1Call> createAllOwnedPlaylistIfNotExists() async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isNotEmpty) {
      final playlistId = allOwnedPlaylistIds.first;
      final playlist = await _dp1FeedService.getPlaylistById(playlistId);
      _cachedAllOwnedPlaylist = playlist;
      return playlist;
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
          endpoint: '${Environment.indexerURL}/v2/graphql',
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
    _cachedAllOwnedPlaylist = created;
    return created;
  }

  Future<DP1Call> getPlaylistById(String id) async {
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
    _onUpdateAllOwnedPlaylist(playlist);
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
    _onUpdateAllOwnedPlaylist(playlist);
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
    addressLastRefreshedTime.clear();
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

  Future<void> updateAddressLastRefreshedTime({
    required List<String> addresses,
    DateTime? dateTime,
  }) async {
    // update the time for the addresses
    final time = dateTime ?? DateTime.now();
    for (var address in addresses) {
      addressLastRefreshedTime[address] = time;
    }
  }

  DateTime getAddressOldestLastRefreshedTime({
    required List<String> addresses,
  }) {
    // find the oldest time, saved in addressLastRefreshedTime
    // if any address in addresses is not in addressLastRefreshedTime, return 1970-01-01
    for (var address in addresses) {
      if (!addressLastRefreshedTime.containsKey(address)) {
        return DateTime(1970, 1, 1);
      }
    }
    return addressLastRefreshedTime.entries
        .where((e) => addresses.contains(e.key))
        .map((e) => e.value)
        .toList()
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Future<void> _onUpdateAllOwnedPlaylist(DP1Call playlist) async {
    log.info('[UserDp1PlaylistService] onUpdateAllOwnedPlaylist');
    final dynamicQuery = playlist.firstDynamicQuery;
    if (dynamicQuery == null) {
      return;
    }
    _cachedAllOwnedPlaylist = playlist;
    final bloc = injector<UserAllOwnCollectionBloc>();
    bloc.add(UpdateDynamicQueryEvent(dynamicQuery: dynamicQuery));
  }
}
