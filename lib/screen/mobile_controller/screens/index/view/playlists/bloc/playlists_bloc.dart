import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_item_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
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
    final dynamicQuery = injector<UserDp1PlaylistService>()
        .cachedAllOwnedPlaylist
        .firstDynamicQuery;
    if (dynamicQuery == null) {
      return LoadPlaylistPaginationResponse(
        playlists: [],
        hasMore: false,
        cursor: null,
      );
    }
    final assetTokenGroupByAddress = injector<IndexerDatabaseAbstract>()
        .getGroupAssetTokensByOwnersGroupByAddress(
      owners: dynamicQuery.params.owners,
    );
    if (assetTokenGroupByAddress.isEmpty) {
      return LoadPlaylistPaginationResponse(
        playlists: [],
        hasMore: false,
        cursor: null,
      );
    }
    final playlists = <PlaylistReference>[];
    for (final addressAssetTokens in assetTokenGroupByAddress) {
      final assetTokens = addressAssetTokens.assetTokens;
      final items = <DP1Item>[];
      for (final assetToken in assetTokens) {
        final item = DP1PlaylistItemExtension.fromAssetToken(token: assetToken);
        items.add(item);
      }
      final title = '${addressAssetTokens.address.name}';
      final playlist = DP1CallExtension.fromItems(
          items: items,
          title: title,
          playlistId: addressAssetTokens.address.address);
      playlists.add(PlaylistReference.fromFeralFileDP1Call(playlist));
    }

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    final topPlaylists = playlists.safeSublist(start, end).toList();
    final nextCursor =
        end < playlists.length ? topPlaylists.length.toString() : null;

    final hasMore = nextCursor != null;

    return LoadPlaylistPaginationResponse(
        playlists: topPlaylists, hasMore: hasMore, cursor: nextCursor);
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
      // Create PlaylistData list for playlists
      final playlistDataList = <PlaylistData>[];
      for (final playlistRef in playlists) {
        final playlist = playlistRef.playlist;

        final channelReference = injector<FeralFileFeedManager>()
            .getCachedChannelReferenceByPlaylist(playlist);
        final creator =
            channelReference != null ? channelReference.channel.title : '';

        playlistDataList.add(
          PlaylistData(
            playlistReference: playlistRef,
            creator: creator,
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
