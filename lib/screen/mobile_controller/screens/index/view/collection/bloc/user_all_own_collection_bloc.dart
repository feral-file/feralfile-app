import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

part 'user_all_own_collection_event.dart';
part 'user_all_own_collection_state.dart';

class UserAllOwnCollectionBloc
    extends Bloc<UserAllOwnCollectionEvent, UserAllOwnCollectionState> {
  final Map<Type, StreamSubscription<List<AssetToken>>?> _tokensStreamSubs = {};
  final Map<Type, Completer<void>?> _activeCompleters = {};
  final Map<String, Timer> _workflowStatusTimers = {};
  DynamicQuery? _dynamicQuery;
  UserAllOwnCollectionBloc(this._tokensService)
      : super(const UserAllOwnCollectionState()) {
    on<FetchTokensOfAddresses>(_onFetchTokensOfAddresses);
    on<UpdateDynamicQueryEvent>(_onUpdateDynamicQuery);
    on<ReloadAssetTokensFromIndexerDatabase>(
        _onReloadAssetTokensFromIndexerDatabase);
    on<ClearDataEvent>(_onClearData);
    on<ReindexAddresses>(_onReindexAddresses);
    on<WorkflowStatusTick>(_onWorkflowStatusTick);
    on<UpdateTokensOfAddresses>(_onUpdateTokensOfAddresses);
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
    // Get addresses for the query
    final dynamicQueryOwners = event.dynamicQuery.params.owners;
    final allAddresses = injector<AddressService>().getAllAddresses();
    final missingAddresses =
        dynamicQueryOwners.where((e) => !allAddresses.contains(e)).toList();
    final owners = [
      ...missingAddresses,
    ].toSet().toList();

    if (missingAddresses.isNotEmpty) {
      add(FetchTokensOfAddresses(addresses: owners));
    }

    if (isSameQuery) {
      add(ReloadAssetTokensFromIndexerDatabase());
    } else {
      add(ReloadAssetTokensFromIndexerDatabase());
    }
  }

  Future<void> _onReindexAddresses(
    ReindexAddresses event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    final addresses = event.addresses;
    if (addresses.isEmpty) return;

    try {
      log.info('[UserAllOwnCollectionBloc] Reindex addresses: $addresses');
      // Emit operation BEFORE calling reindex
      final opId = addresses.join(',');
      final operations = List<IndexingOperation>.from(state.indexingOperations);

      // if the operation already exists, return;
      if (operations.any((op) => op.id == opId)) {
        log.info(
            '[UserAllOwnCollectionBloc] Addresses $addresses already being reindexed: $opId');
        return;
      }
      operations.add(IndexingOperation(id: opId, addresses: addresses));
      emit(state.copyWith(indexingOperations: operations));
      try {
        final result = await _tokensService.reindexAddresses(addresses);

        final workflowId = result.workflowId;
        final runId = result.runId;

        final opKey = '${workflowId}_$runId';
        // Cancel previous timer for this op if any
        _workflowStatusTimers[opKey]?.cancel();

        final startedAt = DateTime.now();
        _workflowStatusTimers[opKey] = Timer.periodic(
          const Duration(seconds: 5),
          (timer) async {
            try {
              // Stop after 10 minutes silently
              if (DateTime.now().difference(startedAt) >
                  const Duration(minutes: 10)) {
                timer.cancel();
                _workflowStatusTimers.remove(opKey);
                return;
              }

              final status = await injector<NftIndexerService>()
                  .getWorkflowStatus(workflowId, runId);
              log.info(
                  '[ReindexAddresses][$opKey] status: ${status.status.toJson()}');
              add(WorkflowStatusTick(
                operationKey: opKey,
                addresses: addresses,
                workflowId: workflowId,
                runId: runId,
                status: status.status,
              ));
            } catch (e, st) {
              // Keep polling despite transient errors
              log.info('[ReindexAddresses][$opKey] poll error: $e');
              Sentry.captureException(e, stackTrace: st);
            }
          },
        );
      } catch (e, st) {
        log.info('[UserAllOwnCollectionBloc] Reindex error: $e');
        Sentry.captureException(e, stackTrace: st);
        operations.removeWhere((op) => op.id == opId);
        emit(state.copyWith(indexingOperations: operations));
        rethrow;
      }
    } catch (e, st) {
      log.info('[UserAllOwnCollectionBloc] Reindex error: $e');
      Sentry.captureException(e, stackTrace: st);
      emit(state.copyWith(
        status: UserAllOwnCollectionStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onFetchTokensOfAddresses(
    FetchTokensOfAddresses event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      log.info('[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] started');
      // If the same type is already being processed, ignore this event
      final subType = event.runtimeType;
      if (isRefreshAssetTokenFromDynamicQueryProcessing) {
        log.info(
            '[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] fetching, ignore');
        return;
      } else {
        log.info(
            '[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] not fetching, start fetching');
      }
      // cancel the previous stream
      await _tokensStreamSubs[subType]?.cancel();
      _tokensStreamSubs[subType] = null;

      final newLastUpdatedAt = DateTime.now();

      final prevCompleter = _activeCompleters[subType];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new fetch load');
      }
      final completer = Completer<void>();
      _activeCompleters[subType] = completer;

      // get the stream
      final stream = await _tokensService.fetchTokensInIsolate(event.addresses);

      final List<AssetToken> collected = [];

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info('[${event.runtimeType}] Received ${tokens.length} tokens');
          collected.addAll(tokens);
          emit(state.copyWith(
            status: UserAllOwnCollectionStatus.loaded,
          ));
          if (tokens.isNotEmpty) {
            add(ReloadAssetTokensFromIndexerDatabase());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          Sentry.captureException('Failed to refresh asset tokens: $error');
          _activeCompleters[subType]?.completeError(error);
        },
        onDone: () {
          emit(state.copyWith(
            status: UserAllOwnCollectionStatus.loaded,
          ));
          log.info(
              '[${event.runtimeType}] Stream done with total ${collected.length} tokens');
          _activeCompleters[subType]?.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
      _tokensStreamSubs[subType] = null;

      final addressMap = {
        for (final addr in event.addresses) addr: newLastUpdatedAt,
      };

      // update the last updated at
      await injector<UserDp1PlaylistService>().updateAddressLastRefreshedTime(
        addresses: addressMap,
      );

      add(ReloadAssetTokensFromIndexerDatabase());
    } catch (e) {
      log.info('[${event.runtimeType}] error $e');
      Sentry.captureException('Failed to refresh asset tokens: $e');
    }
    log.info('[${event.runtimeType}] completed');
  }

  Future<void> _onReloadAssetTokensFromIndexerDatabase(
    ReloadAssetTokensFromIndexerDatabase event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    final owners = _dynamicQuery?.params.owners;
    if (owners == null) {
      emit(state.copyWith(addressAssetTokens: []));
      return;
    }
    final assetTokenGroupByAddress = injector<IndexerDatabaseAbstract>()
        .getGroupAssetTokensByOwnersGroupByAddress(
      owners: _dynamicQuery!.params.owners,
    );
    emit(
      state.copyWith(
        addressAssetTokens: assetTokenGroupByAddress
            .map(
              (e) => AddressAssetTokens(
                address: e.address,
                assetTokens: e.assetTokens,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _onClearData(
    ClearDataEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    // Cancel all timers
    for (final timer in _workflowStatusTimers.values) {
      timer.cancel();
    }
    _workflowStatusTimers.clear();
    _tokensStreamSubs.clear();
    _activeCompleters.clear();
    _dynamicQuery = null;

    emit(const UserAllOwnCollectionState());
  }

  bool get isRefreshAssetTokenFromDynamicQueryProcessing =>
      _tokensStreamSubs[FetchTokensOfAddresses] != null ||
      _activeCompleters[FetchTokensOfAddresses]?.isCompleted == false;

  // Removed deprecated _onPollWorkflowStatus

  Future<void> _onWorkflowStatusTick(
    WorkflowStatusTick event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    final opKey = event.operationKey;
    if (event.status.isDone) {
      _workflowStatusTimers[opKey]?.cancel();
      _workflowStatusTimers.remove(opKey);

      // Remove operation for these addresses from state
      final operations = List<IndexingOperation>.from(state.indexingOperations);
      operations.removeWhere((op) => op.id == event.addresses.join(','));

      if (event.status.isSuccess) {
        emit(state.copyWith(indexingOperations: operations));
        add(FetchTokensOfAddresses(addresses: event.addresses));
      } else if (event.status == WorkflowExecutionStatus.timedOut) {
        // silently stop
        emit(state.copyWith(indexingOperations: operations));
        return;
      } else {
        emit(state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: 'Indexing failed or canceled: ${event.status.toJson()}',
          indexingOperations: operations,
        ));
      }
    }
  }

  Future<void> _onUpdateTokensOfAddresses(
    UpdateTokensOfAddresses event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      log.info(
          '[UserAllOwnCollectionBloc][_onUpdateTokensOfAddresses] started');
      final subType = event.runtimeType;

      // cancel previous stream for this subtype
      await _tokensStreamSubs[subType]?.cancel();
      _tokensStreamSubs[subType] = null;

      final completer = Completer<void>();
      final prevCompleter = _activeCompleters[subType];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new update tokens request');
      }
      _activeCompleters[subType] = completer;

      final now = DateTime.now();
      final addressMap = injector<UserDp1PlaylistService>()
          .getAddressOldestLastRefreshedTime(addresses: event.addresses);

      // get stream from token service (updates from indexer changes)
      final stream = await _tokensService.updateTokensInIsolate(addressMap);

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info('[${event.runtimeType}] Received ${tokens.length} tokens');
          emit(state.copyWith(status: UserAllOwnCollectionStatus.loaded));
          if (tokens.isNotEmpty) {
            add(ReloadAssetTokensFromIndexerDatabase());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          Sentry.captureException('Failed to update asset tokens: $error');
          _activeCompleters[subType]?.completeError(error);
        },
        onDone: () async {
          emit(state.copyWith(status: UserAllOwnCollectionStatus.loaded));

          await injector<UserDp1PlaylistService>()
              .updateAddressLastRefreshedTime(
            addresses: {
              for (final addr in event.addresses) addr: now,
            },
          );
          _activeCompleters[subType]?.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
      _tokensStreamSubs[subType] = null;
      add(ReloadAssetTokensFromIndexerDatabase());
    } catch (e, stackTrace) {
      log.info('[${event.runtimeType}] error $e');
      Sentry.captureException('Failed to update asset tokens: $e',
          stackTrace: stackTrace);
    }
  }

  @override
  Future<void> close() {
    log.info('UserAllOwnCollectionBloc closing, cancelling streams');
    // Cancel all timers
    for (final timer in _workflowStatusTimers.values) {
      timer.cancel();
    }
    _workflowStatusTimers.clear();
    return super.close();
  }
}
