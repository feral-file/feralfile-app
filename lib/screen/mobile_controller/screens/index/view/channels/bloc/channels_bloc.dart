import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'channels_event.dart';
part 'channels_state.dart';

class ChannelsBloc extends AuBloc<ChannelsEvent, ChannelsState> {
  ChannelsBloc({
    required this.channelType,
    this.total,
    this.pageSize = 5,
  }) : super(const ChannelsState()) {
    on<LoadChannelsEvent>(_onLoadChannels);
    on<LoadMoreChannelsEvent>(_onLoadMoreChannels);
    on<RefreshChannelsEvent>(_onRefreshChannels);
  }

  final ChannelType channelType;
  final int? total;
  final int pageSize;
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

  Future<LoadChannelPaginationResponse> _loadCuratedChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
  }) async {
    // Get all cached channels
    final allChannels =
        await injector<FeralFileFeedManager>().getAllCachedChannels();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get channels based on total
    // If total is null, get all channels
    final topChannels = total != null
        ? allChannels.take(total!).toList()
        : allChannels.safeSublist(start, end).toList();

    final nextCursor = end < allChannels.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadChannelPaginationResponse(
      channels: topChannels,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadChannelPaginationResponse> _loadMyChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
  }) async {
    // Get all cached channels
    final allChannels =
        await injector<FeralFileFeedManager>().getAllCachedChannels();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get channels based on total
    // If total is null, get all channels
    final topChannels = total != null
        ? allChannels.take(total!).toList()
        : allChannels.safeSublist(start, end).toList();

    final nextCursor = end < allChannels.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadChannelPaginationResponse(
      channels: topChannels,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadChannelPaginationResponse> _loadGlobalChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
  }) async {
    // Get all cached channels
    final allChannels =
        await injector<FeralFileFeedManager>().getAllCachedChannels();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get channels based on total
    // If total is null, get all channels
    final topChannels = total != null
        ? allChannels.take(total!).toList()
        : allChannels.safeSublist(start, end).toList();

    final nextCursor = end < allChannels.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadChannelPaginationResponse(
      channels: topChannels,
      hasMore: hasMore,
      cursor: nextCursor,
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

      LoadChannelPaginationResponse paginationResponse;
      switch (channelType) {
        case ChannelType.curated:
          paginationResponse = await _loadCuratedChannels(
            emit: emit,
            cursor: cursor,
          );
        case ChannelType.me:
          paginationResponse = await _loadMyChannels(
            emit: emit,
            cursor: cursor,
          );
        case ChannelType.global:
          paginationResponse = await _loadGlobalChannels(
            emit: emit,
            cursor: cursor,
          );
      }

      final channels = paginationResponse.channels;

      final newChannels =
          isLoadMore ? [...state.channels, ...channels] : channels;

      emit(state.copyWith(
        status: ChannelsStateStatus.loaded,
        channels: newChannels,
        hasMore: paginationResponse.hasMore,
        cursor: paginationResponse.cursor,
        error: '',
      ));
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
