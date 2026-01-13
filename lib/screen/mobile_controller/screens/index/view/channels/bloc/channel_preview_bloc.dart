import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'channel_preview_event.dart';
part 'channel_preview_state.dart';

class ChannelPreviewBloc
    extends AuBloc<ChannelPreviewEvent, ChannelPreviewState> {
  ChannelPreviewBloc({
    required ChannelReference channelReference,
    required int channelItemsPageSize,
  })  : _channelReference = channelReference,
        _channelItemsPageSize = channelItemsPageSize,
        super(
          ChannelPreviewInitialState(
            channelReference: channelReference,
          ),
        ) {
    on<GetChannelPreviewEvent>(_onGetChannelPreview);
    on<LoadMoreChannelPreviewItemsEvent>(_onLoadMoreChannelPreviewItems);
  }

  final ChannelReference _channelReference;
  final int _channelItemsPageSize;

  Future<void> _onGetChannelPreview(
    GetChannelPreviewEvent event,
    Emitter<ChannelPreviewState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChannelPreviewLoadingState ||
        currentState is ChannelPreviewLoadingMoreState) {
      log.info(
        '[ChannelPreviewBloc] GetChannelPreviewEvent: already loading for channel ${_channelReference.channel.id}',
      );
      return;
    }

    emit(
      ChannelPreviewLoadingState(
        channelReference: _channelReference,
        creator: currentState.creator,
        items: currentState.items,
        currentItemsPage: currentState.currentItemsPage,
        hasMoreItems: currentState.hasMoreItems,
        isLoadingMore: false,
      ),
    );

    try {
      final playlists = await injector<FeralFileFeedManager>()
          .getAllCachedPlaylistsOfChannels(
              <ChannelReference>[_channelReference]);
      final playlistItems = <DP1Item>[];
      for (final playlist in playlists) {
        playlistItems.addAll(playlist.playlist.items);
      }

      final pageItems = playlistItems.take(_channelItemsPageSize).toList();

      final cids = pageItems.map((item) => item.cid).nonNulls.toList();
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: cids);

      final channelItems = <DP1NowDisplayingItem>[];
      for (final DP1Item item in pageItems) {
        final assetToken =
            assetTokens.firstWhereOrNull((token) => token.cid == item.cid);
        channelItems.add(
          DP1NowDisplayingItem(
            dp1Item: item,
            assetToken: assetToken,
          ),
        );
      }

      final service = injector<FeralFileFeedManager>()
          .getFeedServiceByUrl(_channelReference.url);
      final creator = service?.name ?? '';

      final hasMore = playlistItems.length >= _channelItemsPageSize;

      emit(
        ChannelPreviewLoadedState(
          channelReference: _channelReference,
          creator: creator,
          items: channelItems,
          currentItemsPage: 0,
          hasMoreItems: hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e, stackTrace) {
      log.info(
        '[ChannelPreviewBloc] Error loading preview for channel ${_channelReference.channel.id}: $e',
      );
      emit(
        ChannelPreviewErrorState(
          channelReference: _channelReference,
          creator: state.creator,
          items: state.items,
          currentItemsPage: state.currentItemsPage,
          hasMoreItems: state.hasMoreItems,
          isLoadingMore: false,
          error: e.toString(),
        ),
      );
      Zone.current.handleUncaughtError(e, stackTrace);
    }
  }

  Future<void> _onLoadMoreChannelPreviewItems(
    LoadMoreChannelPreviewItemsEvent event,
    Emitter<ChannelPreviewState> emit,
  ) async {
    final currentState = state;

    log.info(
      '[ChannelPreviewBloc] LoadMoreChannelPreviewItemsEvent: ${_channelReference.channel.id}',
    );

    if (currentState.isLoadingMore) {
      log.info(
        '[ChannelPreviewBloc] LoadMoreChannelPreviewItemsEvent: ${_channelReference.channel.id} already loading more',
      );
      return;
    }

    if (!currentState.hasMoreItems) {
      return;
    }

    try {
      emit(
        ChannelPreviewLoadingMoreState(
          channelReference: _channelReference,
          creator: currentState.creator,
          items: currentState.items,
          currentItemsPage: currentState.currentItemsPage,
          hasMoreItems: currentState.hasMoreItems,
          isLoadingMore: true,
        ),
      );

      final channelPlaylists = await injector<FeralFileFeedManager>()
          .getAllCachedPlaylistsOfChannels(
              <ChannelReference>[_channelReference]);

      final allChannelItems = <DP1Item>[];
      for (final playlist in channelPlaylists) {
        allChannelItems.addAll(playlist.playlist.items);
      }

      final nextPage = currentState.currentItemsPage + 1;
      final start = nextPage * _channelItemsPageSize;
      final end = start + _channelItemsPageSize;

      if (start >= allChannelItems.length) {
        emit(
          currentState.copyWith(
            hasMoreItems: false,
            isLoadingMore: false,
          ),
        );
        return;
      }

      final pageItems = allChannelItems.sublist(
        start,
        end > allChannelItems.length ? allChannelItems.length : end,
      );
      final pageCids =
          pageItems.map((item) => item.cid).whereType<String>().toList();

      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: pageCids);

      final newDisplayingItems = <DP1NowDisplayingItem>[];
      for (final DP1Item dp1Item in pageItems) {
        final assetToken =
            assetTokens.firstWhereOrNull((t) => t.cid == dp1Item.cid);
        newDisplayingItems.add(
          DP1NowDisplayingItem(
            dp1Item: dp1Item,
            assetToken: assetToken,
          ),
        );
      }

      final hasMore = end < allChannelItems.length;

      emit(
        ChannelPreviewLoadedState(
          channelReference: _channelReference,
          creator: currentState.creator,
          items: [...currentState.items, ...newDisplayingItems],
          currentItemsPage: nextPage,
          hasMoreItems: hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e, stackTrace) {
      log.info(
        'Error loading more channel preview items for ${_channelReference.channel.id}: $e',
      );
      emit(
        ChannelPreviewErrorState(
          channelReference: _channelReference,
          creator: currentState.creator,
          items: currentState.items,
          currentItemsPage: currentState.currentItemsPage,
          hasMoreItems: currentState.hasMoreItems,
          isLoadingMore: false,
          error: e.toString(),
        ),
      );
      Zone.current.handleUncaughtError(e, stackTrace);
    }
  }
}
