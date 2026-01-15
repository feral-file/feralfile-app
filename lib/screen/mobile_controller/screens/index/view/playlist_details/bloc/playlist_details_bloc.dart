import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as db;
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
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

          add(GetPlaylistDetailsEvent());
          return;

          // Convert db.Items to AssetTokens
          final tokens = <AssetToken>[];
          for (final item in items) {
            if (item.tokenDataJson != null && item.tokenDataJson!.isNotEmpty) {
              try {
                final tokenMap =
                    json.decode(item.tokenDataJson!) as Map<String, dynamic>;
                tokens.add(AssetToken.fromRest(tokenMap));
              } catch (e) {
                log.info(
                  '[PlaylistDetailsBloc] Error parsing token JSON for '
                  '${item.id}: $e',
                );
              }
            }
          }

          // Only trigger reload if the paginated items (0 to offset)
          // have changed
          final currentItems = state.nowDisplayingItems;
          if (currentItems.isEmpty && tokens.isNotEmpty) {
            // No items loaded yet, trigger initial load
            add(GetPlaylistDetailsEvent());
            return;
          }

          // Use the actual number of loaded items for comparison
          final loadedCount = max(_pageSize, currentItems.length);

          // Build nowDisplayingItems from updated tokens for current pagination
          final updatedItems =
              await DP1NowDisplayingItemListExt.buildFromPlaylist(
            playlist: _playlist,
            offset: 0,
            size: loadedCount,
            initialAssetTokens: tokens,
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
        'PlaylistDetailsLoadedState loaded ${_playlist.id} with '
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
        final allItems = await injector<DriftDatabaseService>()
            .getItemsByPlaylistId(_playlist.id);
        total = allItems.length;
      }

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: nowDisplayingItems,
          hasMore: hasMore,
          offset: offset,
          total: total,
          channelReference: channelReference,
        ),
      );
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
        emit(state.copyWith(hasMore: false));
        return;
      }
      final end = start + newNowDisplayingItems.length;
      final hasMore = newNowDisplayingItems.isNotEmpty;

      emit(
        PlaylistDetailsLoadedState(
          nowDisplayingItems: [
            ...state.nowDisplayingItems,
            ...newNowDisplayingItems,
          ],
          hasMore: hasMore,
          offset: end,
          total: state.total,
        ),
      );
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

  @override
  Future<void> close() {
    log.info('[PlaylistDetailsBloc] Closing, cancelling database subscription');
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
    return super.close();
  }
}
