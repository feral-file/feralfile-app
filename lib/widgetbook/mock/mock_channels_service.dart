import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/services/channels_service.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_mobile_controller.dart';

class MockChannelsService extends ChannelsService {
  MockChannelsService(DP1FeedApi api, String apiKey) : super(api);

  @override
  Future<DP1ChannelsResponse> getChannels({
    String? cursor,
    int? limit,
  }) async {
    // Use shared mock data
    return DP1ChannelsResponse(
      MockMobileControllerData.mockChannels,
      false, // hasMore
      null, // cursor
    );
  }

  @override
  Future<Channel> createChannel(Channel channel) async {
    // Mock creating a channel
    return channel;
  }

  @override
  Future<Channel> getChannelDetail(String channelId) async {
    // Mock channel detail
    return Channel(
      id: channelId,
      slug: 'mock-channel-detail',
      title: 'Mock Channel Detail',
      summary: 'Mock channel detail description',
      created: DateTime.now(),
      playlists: [
        'https://example.com/mock-playlist-detail.json',
      ],
    );
  }
}
