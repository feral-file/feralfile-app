import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_create_playlist_request.dart';
import 'package:autonomy_flutter/screen/mobile_controller/services/channels_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';

class DP1FeedService {
  DP1FeedService(this.api);

  final DP1FeedApi api;

  //
  // PLAYLIST
  // Api for playlist
  //

  final urlmap = <String, String>{};

  // PLAYLIST
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

  Future<DP1Call> updatePlaylist(
      {required String playlistId,
      required DP1CreatePlaylistRequest request,
      bool isSyncToCloud = true}) async {
    final updated = await api.updatePlaylist(playlistId, request.toJson());
    return updated;
  }

  Future<DP1Call> getPlaylistById(String playlistId) async {
    return api.getPlaylistById(playlistId);
  }

  Future<List<DP1Call>> getPlaylistsByChannel(Channel channel) async {
    // map DP1Call Id to url
    final dio = Dio();
    final futures = channel.playlists.map((playlistUrl) async {
      try {
        final response = await dio.get<Map<String, dynamic>>(playlistUrl);
        if (response.statusCode == 200 && response.data != null) {
          final playlist = DP1Call.fromJson(response.data!);
          urlmap.putIfAbsent(playlist.id, () => playlistUrl);
          return playlist;
        }
      } catch (e) {
        log.info('Error when get playlists from channel ${channel.title}: $e');
        return null;
      }
    });
    final results = await Future.wait(futures);
    return results.whereType<DP1Call>().toList();
  }

  Future<List<DP1Call>> getAllPlaylistsFromAllChannel() async {
    final response = await injector<ChannelsService>().getChannels();
    final channels = response.items;

    // Execute all requests in parallel
    final futures = channels.map((c) async {
      try {
        return await getPlaylistsByChannel(c);
      } catch (e) {
        log.info('Error when get playlists from channel ${c.title}: $e');
        return <DP1Call>[]; // Return empty list on error
      }
    });

    final results = await Future.wait(futures);
    return results.expand((list) => list).toList();
  }

  Future<DP1PlaylistResponse> getPlaylistsFromChannels({
    String? cursor,
    int? limit,
  }) async {
    final playlists = await getAllPlaylistsFromAllChannel();
    return DP1PlaylistResponse(playlists, false, null);
  }

  //
  // CHANNEL
  // Api for channel
  //

  Channel? getChannelByPlaylistId(String playlistId) {
    final cachedChannels = injector<ChannelsService>().cachedChannels;
    for (final channel in cachedChannels) {
      for (final playlistUrl in channel.playlists) {
        if (urlmap[playlistId] == playlistUrl) {
          return channel;
        }
      }
    }
    return null;
  }

  Future<DP1PlaylistResponse> getPlaylists({
    String? channelId,
    String? cursor,
    int? limit,
  }) async {
    return api.getAllPlaylists(
      playlistGroupId: channelId,
      cursor: cursor,
      limit: limit,
    );
  }

  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    List<String>? playlistGroupIds,
    String? cursor,
    int? limit,
  }) async {
    return api.getPlaylistItems(
      playlistGroupIds: playlistGroupIds,
      cursor: cursor,
      limit: limit,
    );
  }

// OWNED PLAYLIST
// Api for owned playlist
//

  Future<bool> deletePlaylist(String id) async {
    //TODO: Implement delete playlist
    return true;
  }
}
