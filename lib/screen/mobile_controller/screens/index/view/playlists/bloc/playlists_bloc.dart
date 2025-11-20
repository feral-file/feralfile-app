import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_section.dart';
import 'package:autonomy_flutter/util/dp1_manifest_helper.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'playlists_event.dart';
part 'playlists_state.dart';

class PlaylistsBloc extends AuBloc<PlaylistsEvent, PlaylistsState> {
  PlaylistsBloc({
    required this.playlistType,
    this.total,
    this.pageSize = 5,
  }) : super(const PlaylistsState()) {
    on<LoadPlaylistsEvent>(_onLoadPlaylists);
    on<LoadMorePlaylistsEvent>(_onLoadMorePlaylists);
    on<RefreshPlaylistsEvent>(_onRefreshPlaylists);
  }

  final PlaylistType playlistType;
  final int? total;
  final int pageSize;

  Future<void> _onLoadPlaylists(
    LoadPlaylistsEvent event,
    Emitter<PlaylistsState> emit,
  ) async {
    await _loadPlaylists(
      emit: emit,
      cursor: null,
    );
  }

  Future<void> _onLoadMorePlaylists(
    LoadMorePlaylistsEvent event,
    Emitter<PlaylistsState> emit,
  ) async {
    // Prevent multiple simultaneous load more requests
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    await _loadPlaylists(
      emit: emit,
      cursor: state.cursor,
      isLoadMore: true,
    );
  }

  Future<void> _onRefreshPlaylists(
    RefreshPlaylistsEvent event,
    Emitter<PlaylistsState> emit,
  ) async {
    await _loadPlaylists(
      emit: emit,
      cursor: null,
      isRefresh: true,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadCuratedPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
  }) async {
    // Get all cached playlists
    final allPlaylists =
        await injector<FeralFileFeedManager>().getAllCachedPlaylists();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get playlists based on total
    // If total is null, get all playlists
    final topPlaylists = total != null
        ? allPlaylists.take(total!).toList()
        : allPlaylists.safeSublist(start, end).toList();

    final nextCursor = end < allPlaylists.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadPlaylistPaginationResponse(
      playlists: topPlaylists,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadMyPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
  }) async {
    // Get all cached playlists
    final allPlaylists =
        await injector<FeralFileFeedManager>().getAllCachedPlaylists();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get playlists based on total
    // If total is null, get all playlists
    final topPlaylists = total != null
        ? allPlaylists.take(total!).toList()
        : allPlaylists.safeSublist(start, end).toList();

    final nextCursor = end < allPlaylists.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadPlaylistPaginationResponse(
      playlists: topPlaylists,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadGlobalPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
  }) async {
    // Get all cached playlists
    final allPlaylists =
        await injector<FeralFileFeedManager>().getAllCachedPlaylists();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get playlists based on total
    // If total is null, get all playlists
    final topPlaylists = total != null
        ? allPlaylists.take(total!).toList()
        : allPlaylists.safeSublist(start, end).toList();

    final nextCursor = end < allPlaylists.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadPlaylistPaginationResponse(
      playlists: topPlaylists,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<void> _loadPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    try {
      // Emit appropriate loading state
      if (isLoadMore) {
        emit(state.copyWith(status: PlaylistsStateStatus.loadingMore));
      } else {
        emit(state.copyWith(status: PlaylistsStateStatus.loading));
      }

      LoadPlaylistPaginationResponse paginationResponse;
      switch (playlistType) {
        case PlaylistType.curated:
          paginationResponse =
              await _loadCuratedPlaylists(emit: emit, cursor: cursor);
        case PlaylistType.me:
          paginationResponse =
              await _loadMyPlaylists(emit: emit, cursor: cursor);
        case PlaylistType.global:
          paginationResponse =
              await _loadGlobalPlaylists(emit: emit, cursor: cursor);
      }

      final playlists = paginationResponse.playlists;

      // Collect all unique CIDs from top 5 playlists
      final cids = <String>[];
      for (final playlistRef in playlists) {
        for (final item in playlistRef.playlist.items) {
          if (item.cid != null) {
            cids.add(item.cid!);
          }
        }
      }

      // Load asset tokens for all items in top 5 playlists
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: cids);

      // Fetch DP1 manifests for all items
      final refs = <String>[];
      for (final playlistRef in playlists) {
        for (final item in playlistRef.playlist.items) {
          if (item.ref != null) {
            refs.add(item.ref!);
          }
        }
      }
      final manifests =
          await DP1ManifestHelper.instance.fetchDP1Manifests(refs);

      // Create PlaylistData list for top 5 playlists
      final playlistDataList = <PlaylistData>[];
      for (final playlistRef in playlists) {
        final playlist = playlistRef.playlist;
        final items = <DP1NowDisplayingItem>[];

        for (final dp1Item in playlist.items) {
          final assetToken =
              assetTokens.firstWhereOrNull((t) => t.cid == dp1Item.cid);
          final dp1Manifest =
              dp1Item.ref != null ? manifests[dp1Item.ref] : null;

          items.add(
            DP1NowDisplayingItem(
              dp1Item: dp1Item,
              assetToken: assetToken,
              dp1Manifest: dp1Manifest,
            ),
          );
        }

        playlistDataList.add(
          PlaylistData(
            playlistReference: playlistRef,
            creator: 'Me',
            items: items,
          ),
        );
      }

      final newPlaylists =
          isLoadMore ? [...state.playlists, ...playlists] : playlists;
      final newPlaylistDataList = isLoadMore
          ? [...state.playlistData, ...playlistDataList]
          : playlistDataList;

      emit(state.copyWith(
        status: PlaylistsStateStatus.loaded,
        playlists: newPlaylists,
        playlistData: newPlaylistDataList,
        hasMore: paginationResponse.hasMore,
        cursor: paginationResponse.cursor,
        error: '',
      ));
    } catch (e) {
      emit(
        state.copyWith(
          status: PlaylistsStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}

class LoadPlaylistPaginationResponse {
  final List<PlaylistReference> playlists;
  final bool hasMore;
  final String? cursor;

  LoadPlaylistPaginationResponse({
    required this.playlists,
    required this.hasMore,
    required this.cursor,
  });
}
