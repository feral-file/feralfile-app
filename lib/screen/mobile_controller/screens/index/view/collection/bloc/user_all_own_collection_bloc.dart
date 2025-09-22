import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

part 'user_all_own_collection_event.dart';
part 'user_all_own_collection_state.dart';

class UserAllOwnCollectionBloc
    extends Bloc<UserAllOwnCollectionEvent, UserAllOwnCollectionState> {
  final Map<Type, StreamSubscription<List<CompactedAssetToken>>?>
      _tokensStreamSubs = {};
  final Map<Type, Completer<void>?> _activeCompleters = {};
  DynamicQuery? _dynamicQuery;
  UserAllOwnCollectionBloc(this._tokensService)
      : super(const UserAllOwnCollectionState()) {
    on<LazyLoadAssetTokenFromDynamicQuery>(_onLazyLoad);
    on<RefreshAssetTokenFromDynamicQuery>(_onRefreshLoad);
    on<UpdateDynamicQueryEvent>(_onUpdateDynamicQuery);
    on<ClearDataEvent>(_onClearData);
  }

  final NftTokensService _tokensService;

  void _onUpdateDynamicQuery(
    UpdateDynamicQueryEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) {
    log.info('[UserAllOwnCollectionBloc] onUpdateDynamicQuery');
    log.info(
        '[UserAllOwnCollectionBloc] dynamicQuery: ${event.dynamicQuery.toString()}');
    final isSameQuery = _dynamicQuery == event.dynamicQuery;
    _dynamicQuery = event.dynamicQuery;
    if (isSameQuery) {
      add(RefreshAssetTokenFromDynamicQuery());
    } else {
      add(LazyLoadAssetTokenFromDynamicQuery());
    }
  }

  Future<void> _onLazyLoad(
    LazyLoadAssetTokenFromDynamicQuery event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      if (_dynamicQuery == null) {
        log.info('[${event.runtimeType}] dynamicQuery is null');
        return;
      }
      // If the same type is already being processed, ignore this event
      final subType = event.runtimeType;
      if (isLazyLoadAssetTokenFromDynamicQueryProcessing) {
        log.info('[${event.runtimeType}] same query, ignore');
        return;
      } else {
        log.info('[${event.runtimeType}] new query, proceed. Lazy: true');
      }

      // no cross-event gating: lazy event is independent

      emit(
        state.copyWith(
          status: UserAllOwnCollectionStatus.lazyLoading,
        ),
      );

      // ensure cancel any previous lazy subscription (same type)
      await _tokensStreamSubs[subType]?.cancel();
      _tokensStreamSubs[subType] = null;

      final owners = _dynamicQuery!.params.owners;
      final now = DateTime.now();

      final stream = await _tokensService.getCompactedAssetTokensStream(
        owners,
        pageSize: 20,
      );

      final prevCompleter = _activeCompleters[subType];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new lazy load');
      }
      final completer = Completer<void>();
      _activeCompleters[subType] = completer;
      final List<CompactedAssetToken> accumulated = [];

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info('[${event.runtimeType}] Received ${tokens.length} tokens');
          accumulated.addAll(tokens);
          emit(
            state.copyWith(
              compactedAssetTokens: accumulated,
              status: UserAllOwnCollectionStatus.loaded,
            ),
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          emit(
            state.copyWith(
              status: UserAllOwnCollectionStatus.error,
              error: error.toString(),
            ),
          );
          _activeCompleters[subType]?.completeError(error);
        },
        onDone: () {
          log.info('[${event.runtimeType}] Stream done');
          emit(state.copyWith(status: UserAllOwnCollectionStatus.loaded));
          _activeCompleters[subType]?.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
      _tokensStreamSubs[subType] = null;
      injector<UserDp1PlaylistService>()
          .updateAddressLastRefreshedTime(addresses: owners, dateTime: now);
    } catch (e) {
      log.info('[${event.runtimeType}] error $e');
      Sentry.captureException('Failed to lazy load asset tokens: $e');
      emit(
        state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: e.toString(),
        ),
      );
    }
    log.info('[${event.runtimeType}] completed');
  }

  Future<void> _onRefreshLoad(
    RefreshAssetTokenFromDynamicQuery event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      if (_dynamicQuery == null) {
        log.info('[${event.runtimeType}] dynamicQuery is null');
        return;
      }
      // If the same type is already being processed, ignore this event
      final subType = event.runtimeType;
      if (isRefreshAssetTokenFromDynamicQueryProcessing) {
        log.info('[${event.runtimeType}] same query, ignore');
        return;
      } else if (isLazyLoadAssetTokenFromDynamicQueryProcessing) {
        log.info('[${event.runtimeType}] lazy load is processing, ignore');
        return;
      } else {
        log.info('[${event.runtimeType}] new query, proceed. Lazy: false');
      }
      // cancel the previous stream
      await _tokensStreamSubs[subType]?.cancel();
      _tokensStreamSubs[subType] = null;

      // get the owners
      final owners = _dynamicQuery!.params.owners;
      final lastUpdatedAt = injector<UserDp1PlaylistService>()
          .getAddressOldestLastRefreshedTime(addresses: owners);

      final newLastUpdatedAt = DateTime.now();

      final prevCompleter = _activeCompleters[subType];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new refresh load');
      }
      final completer = Completer<void>();
      _activeCompleters[subType] = completer;

      // get the stream
      final stream = await _tokensService.getCompactedAssetTokensStream(
        owners,
        pageSize: 20,
        lastUpdatedAt: lastUpdatedAt,
      );

      final List<CompactedAssetToken> collected = [];

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info('[${event.runtimeType}] Received ${tokens.length} tokens');
          collected.addAll(tokens);
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          Sentry.captureException('Failed to refresh asset tokens: $error');
          _activeCompleters[subType]?.completeError(error);
        },
        onDone: () {
          log.info(
              '[${event.runtimeType}] Stream done with total ${collected.length} tokens');
          _activeCompleters[subType]?.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
      _tokensStreamSubs[subType] = null;

      // update the last updated at
      injector<UserDp1PlaylistService>().updateAddressLastRefreshedTime(
          addresses: owners, dateTime: newLastUpdatedAt);

      // insert the collected tokens into the state
      final currentTokens = state.compactedAssetTokens.toList();

      // insert the collected tokens into the state and order by lastActivityTime
      currentTokens.addAll(collected);
      currentTokens
          .sort((a, b) => b.lastActivityTime.compareTo(a.lastActivityTime));

      emit(state.copyWith(
        compactedAssetTokens: currentTokens,
      ));
    } catch (e) {
      log.info('[${event.runtimeType}] error $e');
      Sentry.captureException('Failed to refresh asset tokens: $e');
    }
    log.info('[${event.runtimeType}] completed');
  }

  Future<void> _onClearData(
    ClearDataEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    _tokensStreamSubs.clear();
    _activeCompleters.clear();
    _dynamicQuery = null;
    emit(const UserAllOwnCollectionState());
  }

  bool get isLazyLoadAssetTokenFromDynamicQueryProcessing =>
      _tokensStreamSubs[LazyLoadAssetTokenFromDynamicQuery] != null ||
      _activeCompleters[LazyLoadAssetTokenFromDynamicQuery]?.isCompleted ==
          false;

  bool get isRefreshAssetTokenFromDynamicQueryProcessing =>
      _tokensStreamSubs[RefreshAssetTokenFromDynamicQuery] != null ||
      _activeCompleters[RefreshAssetTokenFromDynamicQuery]?.isCompleted ==
          false;

  @override
  Future<void> close() {
    log.info('UserAllOwnCollectionBloc closing, cancelling streams');
    // TODO: implement close
    return super.close();
  }
}
