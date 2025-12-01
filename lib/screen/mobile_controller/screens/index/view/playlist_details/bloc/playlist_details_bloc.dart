import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_item_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

class PlaylistDetailsBloc
    extends AuBloc<PlaylistDetailsEvent, PlaylistDetailsState> {
  PlaylistDetailsBloc({required DP1Call playlist})
      : _playlist = playlist,
        super(const PlaylistDetailsInitialState()) {
    on<SetPlaylistDetailsEvent>(_onSetPlaylistDetails);
    on<GetPlaylistDetailsEvent>(_onGetPlaylistDetails);
    on<LoadMorePlaylistDetailsEvent>(_onLoadMorePlaylistDetails);
  }

  DP1Call _playlist;

  static const int _pageSize = 10;

  /// Build nowDisplayingItems for playlist with static items.
  Future<List<DP1NowDisplayingItem>> _buildNowDisplayingItemsFromStaticItems({
    required int offset,
    required int size,
  }) async {
    final items = _playlist.items;
    final pageItems = items.safeSublist(offset, offset + size);
    if (pageItems.isEmpty) {
      return [];
    }

    final pageCids =
        pageItems.map((item) => item.cid).whereType<String>().toList();
    final pageAssetTokens = <AssetToken>[];

    try {
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: pageCids);

      if (assetTokens.length != pageItems.length) {
        final missingTokens = pageItems
            .where((item) => !assetTokens.any((t) => t.cid == item.cid))
            .toList();
        unawaited(
          Sentry.captureException(
            Exception(
              'Can not get all tokens. Missing tokens:  ${missingTokens.map((t) => t.cid).join(', ')}',
            ),
          ),
        );
      }

      pageAssetTokens.addAll(assetTokens);
    } catch (e) {
      log.info('Error getting tokens: $e');
      unawaited(Sentry.captureException(e));
    }

    // Build nowDisplayingItems list
    final nowDisplayingItems = <DP1NowDisplayingItem>[];
    for (var i = 0; i < pageItems.length; i++) {
      final dp1Item = pageItems[i];
      final assetToken =
          pageAssetTokens.firstWhereOrNull((e) => e.cid == dp1Item.cid);
      nowDisplayingItems.add(
        DP1NowDisplayingItem(
          dp1Item: dp1Item,
          assetToken: assetToken,
        ),
      );
    }

    return nowDisplayingItems;
  }

  /// Build nowDisplayingItems for playlist with dynamic query (owners-based).
  Future<List<DP1NowDisplayingItem>> _buildNowDisplayingItemsFromDynamicQuery({
    required int offset,
    required int size,
  }) async {
    final dynamicQuery = _playlist.firstDynamicQuery;
    if (dynamicQuery == null) {
      log.info(
          '[PlaylistDetailsBloc][_buildNowDisplayingItemsFromDynamicQuery] No dynamic query for playlist ${_playlist.id}');
      return <DP1NowDisplayingItem>[];
    }

    final owners = dynamicQuery.params.owners;
    if (owners.isEmpty) {
      log.info(
          '[PlaylistDetailsBloc][_buildNowDisplayingItemsFromDynamicQuery] Owners empty for playlist ${_playlist.id}');
      return <DP1NowDisplayingItem>[];
    }

    log.info(
        '[PlaylistDetailsBloc][_buildNowDisplayingItemsFromDynamicQuery] Fetching tokens for playlist ${_playlist.id} with owners: $owners, offset: $offset, size: $size');

    // Fetch tokens from indexer via isolate for given owners
    // final tokensStream = await injector<NftTokensService>()
    //     .fetchTokensInIsolate(owners, offset, size);
    // final allTokens = <AssetToken>[];

    // await for (final batch in tokensStream) {
    //   allTokens.addAll(batch);
    // }

    final allTokensOwners = await injector<IndexerDatabaseAbstract>()
        .getTokensByOwner(ownerAddress: owners.first);

    final allTokens = allTokensOwners.safeSublist(offset, offset + size);

    if (allTokens.isEmpty) {
      log.info(
          '[PlaylistDetailsBloc][_buildNowDisplayingItemsFromDynamicQuery] No tokens found for owners: $owners');
      return <DP1NowDisplayingItem>[];
    }

    final pageTokens = allTokens.safeSublist(0, size);
    if (pageTokens.isEmpty) {
      return <DP1NowDisplayingItem>[];
    }

    final pageItems = pageTokens
        .map(
          (token) => DP1PlaylistItemExtension.fromAssetToken(token: token),
        )
        .toList();

    // Build nowDisplayingItems list using tokens directly
    final nowDisplayingItems = <DP1NowDisplayingItem>[];
    for (var i = 0; i < pageItems.length; i++) {
      final dp1Item = pageItems[i];
      final assetToken = pageTokens[i];
      nowDisplayingItems.add(
        DP1NowDisplayingItem(
          dp1Item: dp1Item,
          assetToken: assetToken,
        ),
      );
    }

    log.info(
        '[PlaylistDetailsBloc][_buildNowDisplayingItemsFromDynamicQuery] Returning ${nowDisplayingItems.length} items for playlist ${_playlist.id}');

    return nowDisplayingItems;
  }

  Future<void> _onSetPlaylistDetails(
    SetPlaylistDetailsEvent event,
    Emitter<PlaylistDetailsState> emit,
  ) async {
    _playlist = event.playlist;
    add(GetPlaylistDetailsEvent());
  }

  Future<void> _onGetPlaylistDetails(
    GetPlaylistDetailsEvent event,
    Emitter<PlaylistDetailsState> emit,
  ) async {
    log.info('GetPlaylistDetailsEvent');
    if (state is PlaylistDetailsLoadingState) {
      log.info(
          '[PlaylistDetailsBloc] GetPlaylistDetailsEvent: already loading');
      return;
    }
    emit(
      PlaylistDetailsLoadingState(
        nowDisplayingItems: state.nowDisplayingItems,
        hasMore: state.hasMore,
        offset: state.offset,
      ),
    );
    try {
      final isStatic = _playlist.items.isNotEmpty;
      final nowDisplayingItems = isStatic
          ? await _buildNowDisplayingItemsFromStaticItems(
              offset: 0,
              size: event.size,
            )
          : await _buildNowDisplayingItemsFromDynamicQuery(
              offset: 0,
              size: event.size,
            );

      log.info(
          'PlaylistDetailsLoadedState loaded ${this._playlist.id} with ${nowDisplayingItems.length} items');

      final offset = nowDisplayingItems.length;
      final hasMore = nowDisplayingItems.isNotEmpty;

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: nowDisplayingItems,
          hasMore: hasMore,
          offset: offset,
        ),
      );
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          nowDisplayingItems: state.nowDisplayingItems,
          hasMore: state.hasMore,
          offset: state.offset,
        ),
      );
    }
  }

  Future<void> _onLoadMorePlaylistDetails(
    LoadMorePlaylistDetailsEvent event,
    Emitter<PlaylistDetailsState> emit,
  ) async {
    log.info('[PlaylistDetailsBloc] LoadMorePlaylistDetailsEvent');
    if (state is PlaylistDetailsLoadingMoreState) {
      log.info(
          '[PlaylistDetailsBloc] LoadMorePlaylistDetailsEvent: already loading');
      return;
    }
    if (!state.hasMore) return;
    emit(
      PlaylistDetailsLoadingMoreState(
        nowDisplayingItems: state.nowDisplayingItems,
        hasMore: state.hasMore,
        offset: state.offset,
      ),
    );
    try {
      final isStatic = _playlist.items.isNotEmpty;
      final start = state.offset;

      final newNowDisplayingItems = await (isStatic
              ? _buildNowDisplayingItemsFromStaticItems(
                  offset: start,
                  size: _pageSize,
                )
              : _buildNowDisplayingItemsFromDynamicQuery(
                  offset: start,
                  size: _pageSize,
                ))
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Timeout loading more playlist details');
      });

      if (newNowDisplayingItems.isEmpty) {
        emit(state.copyWith(hasMore: false));
        return;
      }
      final end = start + newNowDisplayingItems.length;
      final hasMore = newNowDisplayingItems.isNotEmpty;

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: [
            ...state.nowDisplayingItems,
            ...newNowDisplayingItems
          ],
          hasMore: hasMore,
          offset: end,
        ),
      );
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          nowDisplayingItems: state.nowDisplayingItems,
          hasMore: state.hasMore,
          offset: state.offset,
        ),
      );
    }
  }
}
