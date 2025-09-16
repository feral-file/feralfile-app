import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'dp1_playlist_api.g.dart';

@RestApi(baseUrl: 'https://api.feed.feralfile.com')
abstract class DP1FeedApi {
  factory DP1FeedApi(Dio dio, {String baseUrl}) = _DP1FeedApi;

  // PLAYLIST
  @POST('/api/v1/playlists')
  Future<DP1Call> createPlaylist(
    @Body() Map<String, dynamic> body,
  );

  @PUT('/api/v1/playlists/{playlistId}')
  Future<DP1Call> updatePlaylist(
    @Path('playlistId') String playlistId,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/api/v1/playlists/{playlistId}')
  Future<void> deletePlaylist(
    @Path('playlistId') String playlistId,
  );

  @GET('/api/v1/playlists/{playlistId}')
  Future<DP1Call> getPlaylistById(
    @Path('playlistId') String playlistId,
  );

  @GET('/api/v1/playlists')
  Future<DP1PlaylistResponse> getAllPlaylists({
    @Query('channel') String? channelId,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });

  // CHANNEL
  @POST('/api/v1/channels')
  Future<Channel> createChannel(
    @Body() Map<String, dynamic> body,
  );

  @GET('/api/v1/channels/{channelId}')
  Future<Channel> getChannelById(
    @Path('channelId') String channelId,
  );

  @GET('/api/v1/channels')
  Future<DP1ChannelsResponse> getAllChannels({
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });

  // PLAYLIST ITEM
  @GET('/api/v1/playlist-items')
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    @Query('channel') String? channelId,
    @Query('cursor') String? cursor,
    @Query('limit') int? limit,
  });
}
