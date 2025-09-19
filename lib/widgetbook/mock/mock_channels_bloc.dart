import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/services/channels_service.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_mobile_controller.dart';

class MockChannelsBloc extends ChannelsBloc {
  MockChannelsBloc({required ChannelsService channelsService})
      : super(dp1FeedService: channelsService);

  @override
  void add(ChannelsEvent event) {
    if (event is LoadChannelsEvent) {
      // Use shared mock data
      emit(ChannelsState(
        status: ChannelsStateStatus.loaded,
        channels: MockMobileControllerData.mockChannels,
        hasMore: false,
        cursor: null,
        error: null,
      ));
    } else if (event is LoadMoreChannelsEvent) {
      // Mock load more channels
      final currentState = state;
      final additionalChannels = [
        Channel(
          id: 'mock-channel-4',
          slug: 'mock-channel-4',
          title: 'Mock Channel 4',
          summary: 'Mock channel description 4',
          created: DateTime.now().subtract(const Duration(days: 4)),
          playlists: [
            'https://example.com/mock-playlist-7.json',
          ],
        ),
      ];

      emit(currentState.copyWith(
        channels: [...currentState.channels, ...additionalChannels],
        status: ChannelsStateStatus.loaded,
        hasMore: false,
      ));
    } else if (event is RefreshChannelsEvent) {
      // Mock refresh channels
      final mockChannels = [
        Channel(
          id: 'mock-refresh-channel-1',
          slug: 'mock-refresh-channel-1',
          title: 'Mock Refresh Channel 1',
          summary: 'Mock refresh channel description 1',
          created: DateTime.now(),
          playlists: [
            'https://example.com/mock-refresh-playlist-1.json',
          ],
        ),
      ];

      emit(ChannelsState(
        status: ChannelsStateStatus.loaded,
        channels: mockChannels,
        hasMore: false,
        cursor: null,
        error: null,
      ));
    } else {
      super.add(event);
    }
  }
}
