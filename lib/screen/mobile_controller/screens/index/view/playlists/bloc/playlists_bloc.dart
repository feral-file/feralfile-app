import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as db;
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/playlist_data_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

part 'playlists_event.dart';
part 'playlists_state.dart';

class PlaylistsBloc extends AuBloc<PlaylistsEvent, PlaylistsState> {
  PlaylistsBloc({
    required this.playlistType,
    this.total,
    this.pageSize = 5,
  }) : super(const PlaylistsState()) {
    // Don't set up listener in constructor - wait for playlists to be loaded
    on<LoadPlaylistsEvent>(_onLoadPlaylists);
    on<LoadMorePlaylistsEvent>(_onLoadMorePlaylists);
    on<RefreshPlaylistsEvent>(_onRefreshPlaylists);

    _setupDatabaseListener(state);
  }

  final PlaylistType playlistType;
  final int? total;
  final int pageSize;
  StreamSubscription<List<db.Playlist>>? _databaseSubscription;

  // @override
  // void onTransition(
  //   Transition<PlaylistsEvent, PlaylistsState> transition,
  // ) {
  //   super.onTransition(transition);
  //   _setupDatabaseListener(transition.nextState);
  // }

  /// Setup database listener to watch for changes in loaded playlists count
  /// based on the given [nextState].
  void _setupDatabaseListener(PlaylistsState nextState) {
    // Cancel existing subscription if any
    _databaseSubscription?.cancel();
    _databaseSubscription = null;

    // Don't watch for global playlists
    if (playlistType == PlaylistType.global) {
      return;
    }

    // Get current loaded playlists length from next state's playlistData
    final loadedLength = nextState.playlistData.length;

    // We only need to observe the visible portion: min(pageSize, loadedLength)
    final listenSize = loadedLength > pageSize ? pageSize : loadedLength;

    log.info(
      '[PlaylistsBloc] Setting up database listener for ${playlistType.name} '
      'with size $listenSize',
    );

    try {
      Stream<List<db.Playlist>> watchStream;

      switch (playlistType) {
        case PlaylistType.curated:
          // Watch DP1 playlists (type=0)
          watchStream = injector<DriftDatabaseService>().watchPlaylistRows(
            kind: DriftPlaylistKind.dp1,
            size: listenSize,
          );
          log.info(
            '[PlaylistsBloc] Setting up database listener '
            'for curated playlists',
          );
        case PlaylistType.me:
          // Watch address playlists (type=1, channelId='my_collection')
          watchStream = injector<DriftDatabaseService>().watchPlaylistRows(
            channelId: 'my_collection',
            kind: DriftPlaylistKind.address,
            size: listenSize,
          );
          log.info(
            '[PlaylistsBloc] Setting up database listener for my playlists',
          );
        case PlaylistType.global:
          // No listener for global playlists
          return;
      }

      _databaseSubscription = watchStream.listen(
        (playlists) async {
          log.info(
            '[PlaylistsBloc] Database changed, checking '
            '${playlistType.name} playlists with ${playlists.length} playlists',
          );

          final currentPlaylists = state.playlistData;

          // If no playlists loaded yet, trigger initial load immediately
          if (currentPlaylists.isEmpty) {
            log.info(
              '[PlaylistsBloc] No playlists loaded yet, triggering initial '
              'load for ${playlistType.name}',
            );
            add(RefreshPlaylistsEvent());
            return;
          }

          // For loaded playlists, check if data actually changed before reloading
          // Use the actual number of loaded playlists for comparison
          final loadedCount = max(pageSize, currentPlaylists.length);

          // Convert database playlist rows to PlaylistData for comparison
          final updatedPlaylists = <PlaylistData>[];
          for (final playlist in playlists) {
            final playlistRef = await injector<FeralFileFeedManager>()
                .getPlaylistReferenceByPlaylistId(
              playlist.id,
            );
            if (playlistRef != null) {
              final creator = await playlistRef.getCreator();
              updatedPlaylists.add(
                PlaylistData(
                  playlistReference: playlistRef,
                  creator: creator,
                ),
              );
            }
          }

          // Compare with current state
          final hasChanged = !currentPlaylists.isEqualTo(updatedPlaylists);

          if (hasChanged) {
            log.info(
              '[PlaylistsBloc] Paginated playlists (0 to $loadedCount) '
              'changed, reloading ${playlistType.name}',
            );
            add(RefreshPlaylistsEvent(size: loadedCount));
          } else {
            log.info(
              '[PlaylistsBloc] Paginated playlists (0 to $loadedCount) '
              'unchanged, skipping reload',
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info(
            '[PlaylistsBloc] Database listener error: $error',
          );
          unawaited(
            Sentry.captureException(
              'Database listener error in PlaylistsBloc: $error',
              stackTrace: stackTrace,
            ),
          );
        },
      );
    } catch (e, s) {
      log.info(
        '[PlaylistsBloc] Error setting up database listener: $e',
      );
      unawaited(
        Sentry.captureException(
          'Error setting up database listener: $e',
          stackTrace: s,
        ),
      );
    }
  }

  Future<void> _onLoadPlaylists(
    LoadPlaylistsEvent event,
    Emitter<PlaylistsState> emit,
  ) async {
    log.info('LoadPlaylistsEvent for ${playlistType.name}');
    await _loadPlaylists(
      emit: emit,
      cursor: null,
    );
    log.info('LoadPlaylistsEvent for ${playlistType.name} done');
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
      loadSize: event.size,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadCuratedPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
    int? loadSize,
  }) async {
    // Get all cached playlists
    final allPlaylists =
        await injector<FeralFileFeedManager>().getAllCachedPlaylists();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final size = loadSize ?? pageSize;
    final end = start + size;

    // Get playlists based on total
    // If total is null, get all playlists
    final topPlaylists = total != null
        ? allPlaylists.take(total!).toList()
        : allPlaylists.safeSublist(start, end).toList();

    final nextCursor = end < allPlaylists.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    final playlistDataList = await Future.wait(
      topPlaylists
          .map(
            (playlistRef) async => PlaylistData(
              playlistReference: playlistRef,
              creator: await playlistRef.getCreator(),
            ),
          )
          .toList(),
    );

    return LoadPlaylistPaginationResponse(
      playlistData: playlistDataList,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadPlaylistPaginationResponse> _loadMyPlaylists({
    required Emitter<PlaylistsState> emit,
    required String? cursor,
    int? loadSize,
  }) async {
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final size = loadSize ?? pageSize;
    final end = start + size;

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
    int? loadSize,
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
          paginationResponse = await _loadCuratedPlaylists(
            emit: emit,
            cursor: cursor,
            loadSize: loadSize,
          );
        case PlaylistType.me:
          paginationResponse = await _loadMyPlaylists(
            emit: emit,
            cursor: cursor,
            loadSize: loadSize,
          );
        case PlaylistType.global:
          paginationResponse =
              await _loadGlobalPlaylists(emit: emit, cursor: cursor);
      }

      final playlistDataList = paginationResponse.playlistData;
      final newPlaylistDataList = isLoadMore
          ? [...state.playlistData, ...playlistDataList]
          : playlistDataList;
      final nextState = state.copyWith(
        status: PlaylistsStateStatus.loaded,
        playlistData: newPlaylistDataList,
        hasMore: paginationResponse.hasMore,
        cursor: paginationResponse.cursor,
        error: '',
      );

      emit(nextState);
      log.info(
        'LoadPlaylistsEvent for ${playlistType.name}: '
        '${newPlaylistDataList.length}',
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PlaylistsStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    log.info('[PlaylistsBloc] Closing, cancelling database subscription');
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
    return super.close();
  }
}

class LoadPlaylistPaginationResponse {
  LoadPlaylistPaginationResponse({
    required this.playlistData,
    required this.hasMore,
    required this.cursor,
  });

  final List<PlaylistData> playlistData;
  final bool hasMore;
  final String? cursor;
}
