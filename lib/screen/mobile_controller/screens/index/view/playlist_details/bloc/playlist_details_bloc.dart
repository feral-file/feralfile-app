import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/util/dp1_manifest_helper.dart';
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
    emit(
      PlaylistDetailsLoadingState(
        nowDisplayingItems: state.nowDisplayingItems,
        hasMore: state.hasMore,
        currentPage: state.currentPage,
      ),
    );
    try {
      final items = _playlist.items;
      final pageItems = items.take(event.size).toList();
      final pageAssetTokens = <AssetToken>[];

      try {
        final cids =
            pageItems.map((item) => item.cid).whereType<String>().toList();

        final assetTokens =
            await injector<NftTokensService>().getManualTokens(cids: cids);
        if (assetTokens.length != pageItems.length) {
          final missingTokens = pageItems
              .where((item) => !assetTokens.any((t) => t.cid == item.cid))
              .toList();
          unawaited(
            Sentry.captureException(
              Exception(
                'Can not get all tokens. Missing tokens:  ${missingTokens.join(', ')}',
              ),
            ),
          );
        }

        final tokens = cids
            .map(
              (cid) => assetTokens.firstWhereOrNull(
                (t) => t.cid == cid,
              ),
            )
            .nonNulls
            .toList();
        pageAssetTokens.addAll(tokens);

        if (assetTokens.length != pageItems.length) {
          final missingTokens = pageItems
              .where((item) => !assetTokens.any((t) => t.cid == item.cid))
              .toList();
          unawaited(
            Sentry.captureException(
              Exception(
                'Can not get all tokens. Missing tokens:  ${missingTokens.join(', ')}',
              ),
            ),
          );
        }
      } catch (e) {
        log.info('Error getting tokens: $e');
        unawaited(Sentry.captureException(e));
      }

      // Fetch DP1 manifests
      final refs =
          pageItems.map((item) => item.ref).whereType<String>().toList();
      final manifests =
          await DP1ManifestHelper.instance.fetchDP1Manifests(refs);

      // Create DP1NowDisplayingItem list by combining dp1Items, assetTokens, and manifests
      final nowDisplayingItems = <DP1NowDisplayingItem>[];
      for (int i = 0; i < pageItems.length; i++) {
        final dp1Item = pageItems[i];
        final assetToken =
            pageAssetTokens.firstWhereOrNull((e) => e.cid == dp1Item.cid);
        final dp1Manifest = manifests[dp1Item.ref];

        nowDisplayingItems.add(
          DP1NowDisplayingItem(
            dp1Item: dp1Item,
            assetToken: assetToken,
            dp1Manifest: dp1Manifest,
          ),
        );
      }

      log.info(
          'PlaylistDetailsLoadedState loaded ${this._playlist.id} with ${nowDisplayingItems.length} items');

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: nowDisplayingItems,
          hasMore: items.length > _pageSize,
          currentPage: 0,
        ),
      );
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          nowDisplayingItems: state.nowDisplayingItems,
          hasMore: state.hasMore,
          currentPage: state.currentPage,
        ),
      );
    }
  }

  Future<void> _onLoadMorePlaylistDetails(
    LoadMorePlaylistDetailsEvent event,
    Emitter<PlaylistDetailsState> emit,
  ) async {
    if (!state.hasMore) return;
    emit(
      PlaylistDetailsLoadingMoreState(
        nowDisplayingItems: state.nowDisplayingItems,
        hasMore: state.hasMore,
        currentPage: state.currentPage,
      ),
    );
    try {
      final items = _playlist.items;
      final nextPage = state.currentPage + 1;
      final start = nextPage * _pageSize;
      final end = start + _pageSize;
      if (start >= items.length) {
        emit(state.copyWith(hasMore: false));
        return;
      }
      final pageItems = items.safeSublist(
        start,
        end,
      );
      final pageCids =
          pageItems.map((item) => item.cid).whereType<String>().toList();

      pageCids.map((e) => '"$e"').toList().join(', ');
      final assetTokens = await injector<NftTokensService>().getManualTokens(
        cids: pageCids,
      );
      final pageAssetTokens = pageCids
          .map(
            (cid) => assetTokens.firstWhere(
              (t) => t.cid == cid,
            ),
          )
          .toList();

      // Fetch DP1 manifests
      final refs =
          pageItems.map((item) => item.ref).whereType<String>().toList();
      final manifests =
          await DP1ManifestHelper.instance.fetchDP1Manifests(refs);

      // Create DP1NowDisplayingItem list by combining dp1Items, assetTokens, and manifests
      final newNowDisplayingItems = <DP1NowDisplayingItem>[];
      for (int i = 0; i < pageItems.length; i++) {
        final dp1Item = pageItems[i];
        final assetToken =
            pageAssetTokens.firstWhereOrNull((e) => e.cid == dp1Item.cid);
        final dp1Manifest = manifests[dp1Item.ref];

        newNowDisplayingItems.add(
          DP1NowDisplayingItem(
            dp1Item: dp1Item,
            assetToken: assetToken,
            dp1Manifest: dp1Manifest,
          ),
        );
      }

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: [
            ...state.nowDisplayingItems,
            ...newNowDisplayingItems
          ],
          hasMore: end < items.length,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          nowDisplayingItems: state.nowDisplayingItems,
          hasMore: state.hasMore,
          currentPage: state.currentPage,
        ),
      );
    }
  }
}
