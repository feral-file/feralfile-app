import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as db;
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/service/thumbnail_prefetch_service.dart';
import 'package:autonomy_flutter/util/dp1_now_displaying_item_ext.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

class PlaylistDetailsBloc
    extends AuBloc<PlaylistDetailsEvent, PlaylistDetailsState> {
  PlaylistDetailsBloc({required DP1Call playlist})
      : _playlist = playlist,
        super(const PlaylistDetailsInitialState()) {
    _setupDatabaseListener();
    on<GetPlaylistDetailsEvent>(_onGetPlaylistDetails);
    on<LoadMorePlaylistDetailsEvent>(_onLoadMorePlaylistDetails);
  }

  final DP1Call _playlist;

  static const int _pageSize = 10;

  StreamSubscription<List<db.Item>>? _databaseSubscription;

  /// Setup database listener to watch for changes.
  void _setupDatabaseListener() {
    // Cancel existing subscription if any
    _databaseSubscription?.cancel();
    _databaseSubscription = null;

    try {
      // Watch playlist items by playlist ID
      final watchStream =
          injector<DriftDatabaseService>().watchPlaylistById(_playlist.id);
      log.info(
        '[PlaylistDetailsBloc] Setting up database listener for playlist '
        '${_playlist.id}',
      );

      _databaseSubscription = watchStream.listen(
        (items) async {
          log.info(
            '[PlaylistDetailsBloc] Database changed, checking playlist '
            '${_playlist.id} with ${items.length} items',
          );

          final currentItems = state.nowDisplayingItems;

          // If no items loaded yet, trigger initial load immediately
          if (currentItems.isEmpty) {
            log.info(
              '[PlaylistDetailsBloc] No items loaded yet, triggering initial '
              'load for playlist ${_playlist.id}',
            );
            add(GetPlaylistDetailsEvent());
            return;
          }

          // For loaded items, check if data actually changed before reloading
          // Use the actual number of loaded items for comparison
          final loadedCount = max(_pageSize, currentItems.length);

          // Build nowDisplayingItems from updated tokens for current pagination
          final updatedItems =
              await DP1NowDisplayingItemListExt.buildFromPlaylist(
            playlist: _playlist,
            offset: 0,
            size: loadedCount,
          );

          // Compare with current state
          final hasChanged = !currentItems.isEqual(updatedItems);

          if (hasChanged) {
            log.info(
              '[PlaylistDetailsBloc] Paginated items (0 to $loadedCount) '
              'changed, reloading playlist ${_playlist.id}',
            );
            add(GetPlaylistDetailsEvent(size: loadedCount));
          } else {
            log.info(
              '[PlaylistDetailsBloc] Paginated items (0 to $loadedCount) '
              'unchanged, skipping reload',
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info(
            '[PlaylistDetailsBloc] Database listener error: $error',
          );
          unawaited(
            Sentry.captureException(
              'Database listener error in PlaylistDetailsBloc: $error',
              stackTrace: stackTrace,
            ),
          );
        },
        onDone: () {
          log.info(
            '[PlaylistDetailsBloc] Database listener done for playlist '
            '${_playlist.id}',
          );
        },
      );
    } catch (e, s) {
      log.info(
        '[PlaylistDetailsBloc] Error setting up database listener: $e',
      );
      unawaited(
        Sentry.captureException(
          'Error setting up database listener: $e',
          stackTrace: s,
        ),
      );
    }
  }

  Future<void> _onGetPlaylistDetails(
    GetPlaylistDetailsEvent event,
    Emitter<PlaylistDetailsState> emit,
  ) async {
    log.info('GetPlaylistDetailsEvent');
    if (state is PlaylistDetailsLoadingState) {
      log.info(
        '[PlaylistDetailsBloc] GetPlaylistDetailsEvent: already loading',
      );
      return;
    }
    emit(
      PlaylistDetailsLoadingState(
        nowDisplayingItems: state.nowDisplayingItems,
        hasMore: state.hasMore,
        offset: state.offset,
        total: state.total,
      ),
    );
    try {
      final channelRow = await injector<DriftDatabaseService>()
          .getChannelByPlaylistId(_playlist.id);
      final channel = channelRow != null
          ? ChannelExtension.fromDriftChannel(channelRow)
          : null;
      final channelReference = await injector<FeralFileFeedManager>()
          .getChannelReferenceByChannelId(channel?.id ?? '');

      final nowDisplayingItems =
          await DP1NowDisplayingItemListExt.buildFromPlaylist(
        playlist: _playlist,
        offset: 0,
        size: event.size,
      );

      log.info(
        '[PlaylistDetailsBloc] [PlaylistDetailsLoadedState] loaded ${_playlist.id} with '
        '${nowDisplayingItems.length} items',
      );

      final offset = nowDisplayingItems.length;
      final hasMore = nowDisplayingItems.isNotEmpty;

      // Calculate total count
      int? total;
      final isStatic = _playlist.items.isNotEmpty;
      if (isStatic) {
        // For static playlists, total is the number of items
        total = _playlist.items.length;
      } else {
        // For dynamic playlists, get total from database items
        total = await injector<DriftDatabaseService>().countItemByPlaylistId(
            _playlist.id,
            type: DriftItemKind.indexerToken);
      }

      log.info(
        '[PlaylistDetailsBloc] [PlaylistDetailsLoadedState] loaded ${_playlist.id} with '
        '${nowDisplayingItems.length} items and total $total',
      );

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: nowDisplayingItems,
          hasMore: hasMore,
          offset: offset,
          total: total,
          channelReference: channelReference,
        ),
      );

      // Trigger background prefetch for next page
      if (hasMore) {
        _prefetchNextPage(nowDisplayingItems.length);
      }
    } catch (e) {
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          nowDisplayingItems: state.nowDisplayingItems,
          hasMore: state.hasMore,
          offset: state.offset,
          total: state.total,
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
        '[PlaylistDetailsBloc] LoadMorePlaylistDetailsEvent: already loading',
      );
      return;
    }
    if (!state.hasMore) return;
    emit(
      PlaylistDetailsLoadingMoreState(
        nowDisplayingItems: state.nowDisplayingItems,
        hasMore: state.hasMore,
        offset: state.offset,
        total: state.total,
      ),
    );
    try {
      final start = state.offset;

      final newNowDisplayingItems =
          await DP1NowDisplayingItemListExt.buildFromPlaylist(
        playlist: _playlist,
        offset: start,
        size: _pageSize,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout loading more playlist details');
        },
      );

      if (newNowDisplayingItems.isEmpty) {
        log.info(
          '[PlaylistDetailsBloc] [PlaylistDetailsLoadedState] no more items to load for ${_playlist.id}',
        );
        emit(state.copyWith(hasMore: false));
        return;
      }
      final end = start + newNowDisplayingItems.length;
      final hasMore = newNowDisplayingItems.isNotEmpty;

      final nowDisplayingItems = [
        ...state.nowDisplayingItems,
        ...newNowDisplayingItems,
      ];

      log.info(
        '[PlaylistDetailsBloc] [PlaylistDetailsLoadedState] loaded more ${_playlist.id}: ${newNowDisplayingItems.length} items /'
        '${nowDisplayingItems.length} items and total ${state.total}, offset $end, hasMore $hasMore',
      );

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: nowDisplayingItems,
          hasMore: hasMore,
          offset: end,
          total: state.total,
        ),
      );

      // Trigger background prefetch for next page
      if (hasMore) {
        _prefetchNextPage(end);
      }
    } catch (e, stackTrace) {
      log.info(
        '[PlaylistDetailsBloc] [PlaylistDetailsErrorState] error loading more playlist details: $e',
      );
      unawaited(
        Sentry.captureException(
          'Error loading more playlist details: $e',
          stackTrace: stackTrace,
        ),
      );
      emit(
        PlaylistDetailsErrorState(
          error: e.toString(),
          nowDisplayingItems: state.nowDisplayingItems,
          hasMore: state.hasMore,
          offset: state.offset,
          total: state.total,
        ),
      );
    }
  }

  /// Prefetch thumbnails for the next page in the background
  void _prefetchNextPage(int currentOffset) {
    try {
      unawaited(() async {
        // Build next page items
        final nextPageItems =
            await DP1NowDisplayingItemListExt.buildFromPlaylist(
          playlist: _playlist,
          offset: currentOffset,
          size: _pageSize,
        );

        if (nextPageItems.isNotEmpty) {
          // Trigger background warm-up prefetch
          // First 10 items go to high priority queue, rest to low priority
          final prefetchService = injector<ThumbnailPrefetchService>();
          await prefetchService.prefetchNowDisplayingItems(
            items: nextPageItems,
            priority: PrefetchPriority.backgroundWarm,
            highPriorityCount: 8,
          );
          log.info(
            '[PlaylistDetailsBloc] Prefetched ${nextPageItems.length} thumbnails for next page '
            '(first 10 in high priority queue)',
          );
        }
      }());
    } catch (e) {
      log.info('[PlaylistDetailsBloc] Error prefetching next page: $e');
      // Non-critical, don't crash
    }
  }

  @override
  Future<void> close() {
    log.info('[PlaylistDetailsBloc] Closing, cancelling database subscription');
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
    return super.close();
  }
}
