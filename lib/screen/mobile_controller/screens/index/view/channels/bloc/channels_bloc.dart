import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel/channel_section.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
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

      final playlists = injector<FeralFileFeedManager>()
          .getAllCachedPlaylistsOfChannels(channels);
      final playlistItems = <DP1Item>[];
      for (final playlist in playlists) {
        playlistItems.addAll(playlist.playlist.items.safeSublist(0, 10));
      }

      final cids = playlistItems.map((item) => item.cid).nonNulls.toList();
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: cids);

      // Create ChannelData list for channels with their items
      final channelDataList = <ChannelData>[];
      for (final channelRef in channels) {
        // Get playlists for this specific channel
        final channelPlaylists = injector<FeralFileFeedManager>()
            .getAllCachedPlaylistsOfChannels([channelRef]);

        // Collect items from all playlists in this channel
        final channelItems = <DP1NowDisplayingItem>[];
        for (final playlist in channelPlaylists) {
          final items = playlist.playlist.items.safeSublist(0, 10);
          for (final item in items) {
            final assetToken =
                assetTokens.firstWhereOrNull((token) => token.cid == item.cid);
            channelItems.add(DP1NowDisplayingItem(
              dp1Item: item,
              assetToken: assetToken,
            ));
          }
        }

        channelDataList.add(
          ChannelData(
            channelReference: channelRef,
            creator: 'Channel',
            items: channelItems,
          ),
        );
      }

      final newChannels =
          isLoadMore ? [...state.channels, ...channels] : channels;
      final newChannelDataList = isLoadMore
          ? [...state.channelData, ...channelDataList]
          : channelDataList;

      emit(state.copyWith(
        status: ChannelsStateStatus.loaded,
        channels: newChannels,
        channelData: newChannelDataList,
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
