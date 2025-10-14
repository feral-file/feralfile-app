import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
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
    emit(
      PlaylistDetailsLoadingState(
        dp1Items: state.dp1Items,
        assetTokens: state.assetTokens,
        hasMore: state.hasMore,
        currentPage: state.currentPage,
      ),
    );
    try {
      final items = _playlist.items;
      final pageItems = items.take(event.size).toList();
      final pageIndexIds =
          pageItems.map((item) => item.indexId).whereType<String>().toList();

      final assetTokens = await injector<NftTokensService>()
          .getManualTokens(indexerIds: pageIndexIds);
      if (assetTokens.length != pageItems.length) {
        final missingTokens = pageItems
            .where((item) => !assetTokens.any((t) => t.id == item.indexId))
            .toList();
        unawaited(
          Sentry.captureException(
            Exception(
              'Can not get all tokens. Missing tokens:  ${missingTokens.join(', ')}',
            ),
          ),
        );
      }

      final pageAssetTokens = pageIndexIds
          .map(
            (id) => assetTokens.firstWhereOrNull(
              (t) => t.id == id,
            ),
          )
          .nonNulls
          .toList();

      if (assetTokens.length != pageItems.length) {
        final missingTokens = pageItems
            .where((item) => !assetTokens.any((t) => t.id == item.indexId))
            .toList();
        unawaited(
          Sentry.captureException(
            Exception(
              'Can not get all tokens. Missing tokens:  ${missingTokens.join(', ')}',
            ),
          ),
        );
      }

      emit(
        PlaylistDetailsLoadedState(
          dp1Items: pageItems,
          assetTokens: pageAssetTokens,
          hasMore: items.length > _pageSize,
          currentPage: 0,
        ),
      );
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          dp1Items: state.dp1Items,
          assetTokens: state.assetTokens,
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
        dp1Items: state.dp1Items,
        assetTokens: state.assetTokens,
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
      final pageItems = items.sublist(
        start,
        end > items.length ? items.length : end,
      );
      final pageIndexIds =
          pageItems.map((item) => item.indexId).whereType<String>().toList();
      pageIndexIds.map((e) => '"$e"').toList().join(', ');
      final assetTokens = await injector<NftTokensService>().getManualTokens(
        indexerIds: pageIndexIds,
      );
      final pageAssetTokens = pageIndexIds
          .map(
            (id) => assetTokens.firstWhere(
              (t) => t.id == id,
            ),
          )
          .toList();
      emit(
        PlaylistDetailsLoadedState(
          dp1Items: [...state.dp1Items, ...pageItems],
          assetTokens: [...state.assetTokens, ...pageAssetTokens],
          hasMore: end < items.length,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          dp1Items: state.dp1Items,
          assetTokens: state.assetTokens,
          hasMore: state.hasMore,
          currentPage: state.currentPage,
        ),
      );
    }
  }
}
