import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/util/log.dart';

import 'dp1_playlist_service.dart';

/// A high-level service to manage a user's DP1 playlists.
///
/// This service coordinates between the remote DP1 feed API (via DP1FeedService)
/// and local cloud storage (via CloudManager.dp1FeedCloudObject).
class UserDp1PlaylistService {
  UserDp1PlaylistService(this._dp1FeedService, this._cloudManager);

  final DP1FeedService _dp1FeedService;
  final CloudManager _cloudManager;

  /// Create a new playlist remotely and cache it locally under owned playlists.
  Future<DP1Call> createAllOwnedPlaylistIfNotExists(
      DP1CreatePlaylistRequest request) async {
    final allOwnedPlaylistIds =
        _cloudManager.dp1FeedCloudObject.getOwnedPlaylistIds();
    if (allOwnedPlaylistIds.isNotEmpty) {
      final playlistId = allOwnedPlaylistIds.first;
      final playlist = _dp1FeedService.getPlaylistById(playlistId);
      return playlist;
    }

    final created = await _dp1FeedService.createPlaylist(
      request: request,
      isSyncToCloud: true,
    );

    _cloudManager.dp1FeedCloudObject.addOwnedPlaylistId(created.id);
    return created;
  }

  Future<DP1Call> getPlaylistById(String id) async {
    final playlist = _dp1FeedService.getPlaylistById(id);
    return playlist;
  }

  Future<DP1Call> insertAddressesToPlaylist(
      String playlistId, List<String> addresses) async {
    final playlist =
        _dp1FeedService.insertAddressesToPlaylist(playlistId, addresses);
    return playlist;
  }

  Future<bool> deletePlaylist(String id) async {
    try {
      final deleted = _dp1FeedService.deletePlaylist(id);
      return deleted;
    } catch (e) {
      log.info('Failed to delete playlist: $e');
      return false;
    }
  }
}
