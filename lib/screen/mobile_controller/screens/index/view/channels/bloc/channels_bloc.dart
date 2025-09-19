import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/util/feed_cache_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'channels_event.dart';
part 'channels_state.dart';

class ChannelsBloc extends Bloc<ChannelsEvent, ChannelsState> {
  ChannelsBloc({
    required DP1FeedService dp1FeedService,
  })  : _dp1FeedService = dp1FeedService,
        super(const ChannelsState()) {
    on<LoadChannelsEvent>(_onLoadChannels);
    on<LoadMoreChannelsEvent>(_onLoadMoreChannels);
    on<RefreshChannelsEvent>(_onRefreshChannels);
  }

  static const int _pageSize = 10;

  final DP1FeedService _dp1FeedService;

  Future<void> _onLoadChannels(
    LoadChannelsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    await _loadChannels(
      emit: emit,
      cursor: null,
    );
  }

  Future<void> _onLoadMoreChannels(
    LoadMoreChannelsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    // Prevent multiple simultaneous load more requests
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    await _loadChannels(
      emit: emit,
      cursor: state.cursor,
      isLoadMore: true,
    );
  }

  Future<void> _onRefreshChannels(
    RefreshChannelsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    await _loadChannels(
      emit: emit,
      cursor: null,
      isRefresh: true,
    );
  }

  Future<void> _loadChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    try {
      // Emit appropriate loading state
      if (isLoadMore) {
        emit(state.copyWith(status: ChannelsStateStatus.loadingMore));
      } else {
        emit(state.copyWith(status: ChannelsStateStatus.loading));
      }

      final channelsResponse = await _dp1FeedService.getAllChannels(
        cursor: cursor,
        limit: _pageSize,
        usingCache: FeedCacheManager().hasCache,
      );

      final List<Channel> newChannels;
      if (isLoadMore) {
        newChannels = [...state.channels, ...channelsResponse.items];
      } else {
        newChannels = channelsResponse.items;
      }

      emit(
        state.copyWith(
          status: ChannelsStateStatus.loaded,
          channels: newChannels,
          hasMore: channelsResponse.hasMore,
          cursor: channelsResponse.cursor,
          error: '',
        ),
      );
    } catch (e) {
      log.info('Error loading channels: $e');
      emit(
        state.copyWith(
          status: ChannelsStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
