import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
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
    log.info("LoadPlaylistsEvent for ${playlistType.name}");
    await _loadPlaylists(
      emit: emit,
      cursor: null,
    );
    log.info("LoadPlaylistsEvent for ${playlistType.name} done");
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

    final playlistDataList = await Future.wait(topPlaylists
        .map(
          (playlistRef) async => PlaylistData(
            playlistReference: playlistRef,
            creator: await playlistRef.getCreator(),
          ),
        )
        .toList());

    return LoadPlaylistPaginationResponse(
      playlistData: playlistDataList,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadMyPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
  }) async {
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    final addressPlaylists =
        await injector<DriftDatabaseService>().getAddressPlaylistsAsDp1Calls();

    final topAddressPlaylists =
        addressPlaylists.safeSublist(start, end).toList();

    final playlistDataList = <PlaylistData>[];
    for (final addressPlaylist in topAddressPlaylists) {
      final playlistRef = PlaylistReference(
        playlist: addressPlaylist,
        url: '',
        type: PlaylistReferenceType.address,
      );
      final creator = await playlistRef.getCreator();
      playlistDataList
          .add(PlaylistData(playlistReference: playlistRef, creator: creator));
    }

    final nextCursor = end < addressPlaylists.length
        ? (topAddressPlaylists.length + start).toString()
        : null;

    final hasMore = nextCursor != null;

    return LoadPlaylistPaginationResponse(
      playlistData: playlistDataList,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadGlobalPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
  }) async {
    return LoadPlaylistPaginationResponse(
      playlistData: [],
      hasMore: false,
      cursor: null,
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

      final playlistDataList = paginationResponse.playlistData;
      final playlists =
          playlistDataList.map((data) => data.playlistReference).toList();

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
      log.info(
          "LoadPlaylistsEvent for ${playlistType.name}: ${newPlaylists.length}");
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
  final List<PlaylistData> playlistData;
  final bool hasMore;
  final String? cursor;

  LoadPlaylistPaginationResponse({
    required this.playlistData,
    required this.hasMore,
    required this.cursor,
  });
}
