import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';

/// Base class for DP1 feed services containing common playlist and item methods
abstract class BaseDP1FeedService {
  BaseDP1FeedService();
  /*
  =======================================================================

  PLAYLIST
  
  =======================================================================
  */

  /// Create a new playlist
  Future<DP1Call> createPlaylist({
    required DP1CreatePlaylistRequest request,
    bool isSyncToCloud = true,
  });

  /// Update an existing playlist
  Future<DP1Call> updatePlaylist({
    required String playlistId,
    required DP1CreatePlaylistRequest request,
    bool isSyncToCloud = true,
  });

  /// Get playlist by ID
  Future<DP1Call> getPlaylistById(
    String playlistId, {
    bool usingCache = true,
  });

  /// Get all playlists with pagination
  Future<DP1PlaylistResponse> getAllPlaylists({
    String? cursor,
    int? limit,
    bool usingCache = true,
  });

  /// Delete a playlist
  Future<bool> deletePlaylist(String id);

  /*
  =======================================================================

  PLAYLIST ITEMS

  =======================================================================
  */

  /// Get playlist items with pagination
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
    bool usingCache = true,
  });
}
