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
    this.channelItemsPageSize = 10,
  }) : super(const ChannelsState()) {
    on<LoadChannelsEvent>(_onLoadChannels);
    on<LoadMoreChannelsEvent>(_onLoadMoreChannels);
    on<RefreshChannelsEvent>(_onRefreshChannels);
    on<LoadMoreChannelItemsEvent>(_onLoadMoreChannelItems);
  }

  final ChannelType channelType;
  final int? total;
  final int pageSize;
  final int channelItemsPageSize;
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

      // Create ChannelData list for channels with their items
      final channelDataList = <ChannelData>[];
      for (final channelRef in channels) {
        final playlists = injector<FeralFileFeedManager>()
            .getAllCachedPlaylistsOfChannels([channelRef]);
        final playlistItems = <DP1Item>[];
        for (final playlist in playlists) {
          playlistItems.addAll(playlist.playlist.items);
        }

        final pageItems = playlistItems.safeSublist(0, channelItemsPageSize);

        final cids = pageItems.map((item) => item.cid).nonNulls.toList();
        final assetTokens =
            await injector<NftTokensService>().getManualTokens(cids: cids);

        // Collect items from all playlists in this channel
        final channelItems = <DP1NowDisplayingItem>[];
        for (final item in pageItems) {
          final assetToken =
              assetTokens.firstWhereOrNull((token) => token.cid == item.cid);
          channelItems.add(DP1NowDisplayingItem(
            dp1Item: item,
            assetToken: assetToken,
          ));
        }

        final service = injector<FeralFileFeedManager>()
            .getFeedServiceByUrl(channelRef.url);
        final creator = service?.name ?? '';

        final currentItemsPage = 0;
        final hasMore = playlistItems.length >= channelItemsPageSize;

        channelDataList.add(
          ChannelData(
            channelReference: channelRef,
            creator: creator,
            items: channelItems,
            currentItemsPage: 0,
            hasMoreItems: hasMore,
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

  Future<void> _onLoadMoreChannelItems(
    LoadMoreChannelItemsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    log.info('[ChannelsBloc] LoadMoreChannelItemsEvent: ${event.channelId}');

    // Find the channel data to update
    final channelDataIndex = state.channelData.indexWhere(
      (data) => data.channelReference.channel.id == event.channelId,
    );

    if (channelDataIndex == -1) {
      log.info('Channel not found: ${event.channelId}');
      return;
    }

    final channelData = state.channelData[channelDataIndex];

    if (channelData.isLoadingMore) {
      log.info(
          '[ChannelsBloc] LoadMoreChannelItemsEvent: ${event.channelId} already loading');
      return;
    }

    log.info(
        '[ChannelsBloc] LoadMoreChannelItemsEvent: ${event.channelId} loading more');

    // Check if there are more items to load
    if (!channelData.hasMoreItems) {
      return;
    }

    try {
      final loadingMoreChannelData = channelData.copyWith(
        isLoadingMore: true,
      );

      final loadingMoreChannelDataList = [...state.channelData];
      loadingMoreChannelDataList[channelDataIndex] = loadingMoreChannelData;

      emit(state.copyWith(
        channelData: loadingMoreChannelDataList,
        status: ChannelsStateStatus.loaded,
      ));
      // Get playlists for this channel
      final channelPlaylists = injector<FeralFileFeedManager>()
          .getAllCachedPlaylistsOfChannels([channelData.channelReference]);

      // Collect all items from playlists
      final allChannelItems = <DP1Item>[];
      for (final playlist in channelPlaylists) {
        allChannelItems.addAll(playlist.playlist.items);
      }

      // Calculate pagination
      final nextPage = channelData.currentItemsPage + 1;
      final start = nextPage * channelItemsPageSize;
      final end = start + channelItemsPageSize;

      if (start >= allChannelItems.length) {
        // No more items to load
        return;
      }

      // Get the page items
      final pageItems = allChannelItems.safeSublist(start, end);
      final pageCids =
          pageItems.map((item) => item.cid).whereType<String>().toList();

      // Get asset tokens for the page items
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: pageCids);

      // Create DP1NowDisplayingItem list
      final newDisplayingItems = <DP1NowDisplayingItem>[];
      for (int i = 0; i < pageItems.length; i++) {
        final dp1Item = pageItems[i];
        final assetToken =
            assetTokens.firstWhereOrNull((t) => t.cid == dp1Item.cid);
        newDisplayingItems.add(
          DP1NowDisplayingItem(
            dp1Item: dp1Item,
            assetToken: assetToken,
          ),
        );
      }

      // Determine if there are more items to load
      final hasMore = end < allChannelItems.length;

      // Update the channel data with new items and pagination info
      final updatedChannelData = channelData.copyWith(
        items: [...channelData.items, ...newDisplayingItems],
        currentItemsPage: nextPage,
        hasMoreItems: hasMore,
        isLoadingMore: false,
      );

      // get the index
      final updatedChannelDataIndex = state.channelData.indexWhere(
          (data) => data.channelReference.channel.id == event.channelId);

      if (updatedChannelDataIndex == -1) {
        log.info('Channel not found: ${event.channelId}');
        return;
      }

      // Update the state
      final updatedChannelDataList = [...state.channelData];
      updatedChannelDataList[updatedChannelDataIndex] = updatedChannelData;

      emit(state.copyWith(
        channelData: updatedChannelDataList,
        status: ChannelsStateStatus.loaded,
      ));
    } catch (e) {
      log.info('Error loading more channel items for ${event.channelId}: $e');
      emit(
        state.copyWith(
          status: ChannelsStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
