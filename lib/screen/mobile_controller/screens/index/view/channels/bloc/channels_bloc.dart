import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart'
    as db;
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

part 'channels_event.dart';
part 'channels_state.dart';

class ChannelsBloc extends AuBloc<ChannelsEvent, ChannelsState> {
  ChannelsBloc({
    required this.channelType,
    this.total,
    this.pageSize = 5,
  }) : super(const ChannelsState()) {
    on<LoadChannelsEvent>(_onLoadChannels);
    on<LoadMoreChannelsEvent>(_onLoadMoreChannels);
    on<RefreshChannelsEvent>(_onRefreshChannels);

    _setupDatabaseListener(state);
  }

  final ChannelType channelType;
  final int? total;
  final int pageSize;
  StreamSubscription<List<db.Channel>>? _databaseSubscription;

  void _setupDatabaseListener(ChannelsState nextState) {
    _databaseSubscription?.cancel();
    _databaseSubscription = null;

    if (channelType == ChannelType.global) {
      return;
    }

    final loadedLength = nextState.channels.length;
    final listenSize = loadedLength > pageSize ? pageSize : loadedLength;

    log.info(
      '[ChannelsBloc] Setting up database listener for ${channelType.name} '
      'with size $listenSize',
    );

    try {
      Stream<List<db.Channel>> watchStream;

      switch (channelType) {
        case ChannelType.curated:
          watchStream = injector<DriftDatabaseService>().watchChannelRows(
            kind: DriftChannelKind.dp1,
            size: listenSize,
          );
          log.info(
            '[ChannelsBloc] Setting up database listener '
            'for curated channels',
          );
        case ChannelType.me:
          watchStream = injector<DriftDatabaseService>().watchChannelRows(
            kind: DriftChannelKind.localVirtual,
            size: listenSize,
          );
          log.info(
            '[ChannelsBloc] Setting up database listener for my channels',
          );
        case ChannelType.global:
          return;
      }

      _databaseSubscription = watchStream.listen(
        (channels) async {
          log.info(
            '[ChannelsBloc] Database changed, reloading '
            '${channelType.name} channels with ${channels.length} channels',
          );

          add(const RefreshChannelsEvent());
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info(
            '[ChannelsBloc] Database listener error: $error',
          );
          unawaited(
            Sentry.captureException(
              'Database listener error in ChannelsBloc: $error',
              stackTrace: stackTrace,
            ),
          );
        },
      );
    } catch (e, s) {
      log.info(
        '[ChannelsBloc] Error setting up database listener: $e',
      );
      unawaited(
        Sentry.captureException(
          'Error setting up database listener: $e',
          stackTrace: s,
        ),
      );
    }
  }

  Future<void> _onLoadChannels(
    LoadChannelsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    await _loadChannels(
      emit: emit,
      cursor: null,
    );
  }

  Future<void> _onLoadMoreChannels(
    LoadMoreChannelsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    // Prevent multiple simultaneous load more requests
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    await _loadChannels(
      emit: emit,
      cursor: state.cursor,
      isLoadMore: true,
    );
  }

  Future<void> _onRefreshChannels(
    RefreshChannelsEvent event,
    Emitter<ChannelsState> emit,
  ) async {
    await _loadChannels(
      emit: emit,
      cursor: null,
      isRefresh: true,
    );
  }

  Future<LoadChannelPaginationResponse> _loadCuratedChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
  }) async {
    // Get all cached channels
    final allChannels =
        await injector<FeralFileFeedManager>().getAllCachedChannels();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get channels based on total
    // If total is null, get all channels
    final topChannels = total != null
        ? allChannels.take(total!).toList()
        : allChannels.safeSublist(start, end).toList();

    final nextCursor = end < allChannels.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadChannelPaginationResponse(
      channels: topChannels,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadChannelPaginationResponse> _loadMyChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
  }) async {
    // Get all cached channels
    final allChannels =
        await injector<FeralFileFeedManager>().getAllCachedChannels();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get channels based on total
    // If total is null, get all channels
    final topChannels = total != null
        ? allChannels.take(total!).toList()
        : allChannels.safeSublist(start, end).toList();

    final nextCursor = end < allChannels.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadChannelPaginationResponse(
      channels: topChannels,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<LoadChannelPaginationResponse> _loadGlobalChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
  }) async {
    // Get all cached channels
    final allChannels =
        await injector<FeralFileFeedManager>().getAllCachedChannels();

    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = start + pageSize;

    // Get channels based on total
    // If total is null, get all channels
    final topChannels = total != null
        ? allChannels.take(total!).toList()
        : allChannels.safeSublist(start, end).toList();

    final nextCursor = end < allChannels.length ? end.toString() : null;
    final hasMore = nextCursor != null;

    return LoadChannelPaginationResponse(
      channels: topChannels,
      hasMore: hasMore,
      cursor: nextCursor,
    );
  }

  Future<void> _loadChannels({
    required Emitter<ChannelsState> emit,
    required String? cursor,
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    try {
      // Emit appropriate loading state
      if (isLoadMore) {
        emit(state.copyWith(status: ChannelsStateStatus.loadingMore));
      } else {
        emit(state.copyWith(status: ChannelsStateStatus.loading));
      }

      LoadChannelPaginationResponse paginationResponse;
      switch (channelType) {
        case ChannelType.curated:
          paginationResponse = await _loadCuratedChannels(
            emit: emit,
            cursor: cursor,
          );
        case ChannelType.me:
          paginationResponse = await _loadMyChannels(
            emit: emit,
            cursor: cursor,
          );
        case ChannelType.global:
          paginationResponse = await _loadGlobalChannels(
            emit: emit,
            cursor: cursor,
          );
      }

      final channels = paginationResponse.channels;

      final newChannels =
          isLoadMore ? [...state.channels, ...channels] : channels;

      final nextState = state.copyWith(
        status: ChannelsStateStatus.loaded,
        channels: newChannels,
        hasMore: paginationResponse.hasMore,
        cursor: paginationResponse.cursor,
        error: '',
      );

      emit(nextState);
      _setupDatabaseListener(nextState);
    } catch (e) {
      log.info('Error loading channels: $e');
      emit(
        state.copyWith(
          status: ChannelsStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    log.info('[ChannelsBloc] Closing, cancelling database subscription');
    _databaseSubscription?.cancel();
    _databaseSubscription = null;
    return super.close();
  }
}
