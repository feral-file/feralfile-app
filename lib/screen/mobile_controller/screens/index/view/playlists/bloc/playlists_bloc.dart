import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
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
  }) : super(const PlaylistsState()) {
    on<LoadPlaylistsEvent>(_onLoadPlaylists);
    on<LoadMorePlaylistsEvent>(_onLoadMorePlaylists);
    on<RefreshPlaylistsEvent>(_onRefreshPlaylists);
  }

  final PlaylistType playlistType;
  final int? total;

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

      // Get all cached playlists
      final allPlaylists =
          await injector<FeralFileFeedManager>().getAllCachedPlaylists();

      // Get playlists based on total
      // If total is null, get all playlists
      final topPlaylists =
          total != null ? allPlaylists.take(total!).toList() : allPlaylists;

      // Collect all unique CIDs from top 5 playlists
      final cids = <String>[];
      for (final playlistRef in topPlaylists) {
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
      for (final playlistRef in topPlaylists) {
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
      for (final playlistRef in topPlaylists) {
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

      emit(state.copyWith(
        status: PlaylistsStateStatus.loaded,
        playlists: topPlaylists,
        playlistData: playlistDataList,
        hasMore: false,
        cursor: null,
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
