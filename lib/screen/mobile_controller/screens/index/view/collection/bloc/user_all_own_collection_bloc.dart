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
    on<PollWorkflowStatus>(_onPollWorkflowStatus);
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
      if (event.shouldEmitLoading) {
        log.info(
            '[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] emit loading state');
        emit(state.copyWith(status: UserAllOwnCollectionStatus.loading));
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
      if (event.shouldEmitLoading) {
        emit(state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: e.toString(),
        ));
      }
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

  Future<void> _onPollWorkflowStatus(
    PollWorkflowStatus event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    final operationKey = event.addresses.join(',');

    // Cancel existing timer for these addresses if any
    _workflowStatusTimers[operationKey]?.cancel();
    _workflowStatusTimers.remove(operationKey);

    // Create indexing operation with workflowId and runId if provided
    final operation = IndexingOperation(
      addresses: event.addresses,
      workflowId: event.workflowId,
      runId: event.runId,
    );

    final currentOperations =
        List<IndexingOperation>.from(state.indexingOperations);

    // Remove existing operation with same addresses if any
    currentOperations.removeWhere((op) => op.key == operationKey);

    // Add new operation
    currentOperations.add(operation);

    // Emit state with operation (workflowId/runId may be null if not provided yet)
    emit(state.copyWith(
      indexingOperations: currentOperations,
    ));

    // If workflowId and runId are not provided, just emit state and return
    // (caller should call again with workflowId/runId after getting them)
    if (event.workflowId == null || event.runId == null) {
      log.info(
        '[PollWorkflowStatus] Waiting for workflowId and runId for addresses: ${event.addresses}',
      );
      return;
    }

    // Start polling workflow status
    final indexerService = injector<NftIndexerService>();
    final startTime = DateTime.now();
    const timeoutDuration = Duration(minutes: 10);
    const pollInterval = Duration(seconds: 5);

    log.info(
      '[PollWorkflowStatus] Starting poll for workflowId: ${event.workflowId}, runId: ${event.runId}',
    );

    // Poll workflow status every 5 seconds (dispatch tick events instead of emitting here)
    final timer = Timer.periodic(pollInterval, (timer) async {
      try {
        // Check timeout
        if (DateTime.now().difference(startTime) >= timeoutDuration) {
          timer.cancel();
          _workflowStatusTimers.remove(operationKey);
          log.info(
            '[PollWorkflowStatus] Timeout after 10 minutes, stopping poll for workflowId: ${event.workflowId}, runId: ${event.runId}',
          );
          add(WorkflowStatusTick(
            operationKey: operationKey,
            addresses: event.addresses,
            workflowId: event.workflowId!,
            runId: event.runId!,
            status: WorkflowExecutionStatus.timedOut,
          ));
          return;
        }

        // Get workflow status
        final workflowStatus = await indexerService.getWorkflowStatus(
          event.workflowId!,
          event.runId!,
        );

        log.info(
          '[PollWorkflowStatus] Status: ${workflowStatus.status.toJson()} for workflowId: ${event.workflowId}, runId: ${event.runId}',
        );

        add(WorkflowStatusTick(
          operationKey: operationKey,
          addresses: event.addresses,
          workflowId: event.workflowId!,
          runId: event.runId!,
          status: workflowStatus.status,
        ));
      } catch (e, stackTrace) {
        log.info('[PollWorkflowStatus] Error: $e');
        Sentry.captureException(
          'Failed to poll workflow status: $e',
          stackTrace: stackTrace,
        );
        // Don't cancel timer on error, continue polling
      }
    });

    _workflowStatusTimers[operationKey] = timer;
  }

  Future<void> _onWorkflowStatusTick(
    WorkflowStatusTick event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    // Timeout: stop polling and remove operation
    if (event.status == WorkflowExecutionStatus.timedOut) {
      final finalOperations =
          List<IndexingOperation>.from(state.indexingOperations);
      finalOperations.removeWhere((op) => op.key == event.operationKey);
      emit(state.copyWith(indexingOperations: finalOperations));
      return;
    }

    if (event.status.isDone) {
      _workflowStatusTimers[event.operationKey]?.cancel();
      _workflowStatusTimers.remove(event.operationKey);

      final finalOperations =
          List<IndexingOperation>.from(state.indexingOperations);
      finalOperations.removeWhere((op) => op.key == event.operationKey);

      if (event.status.isSuccess) {
        emit(state.copyWith(indexingOperations: finalOperations));
        add(FetchTokensOfAddresses(
            addresses: event.addresses, shouldEmitLoading: true));
      } else {
        emit(state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: 'Workflow ${event.status.toJson().toLowerCase()}',
          indexingOperations: finalOperations,
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

      if (event.shouldEmitLoading) {
        emit(state.copyWith(status: UserAllOwnCollectionStatus.loading));
      }

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
      if (event.shouldEmitLoading) {
        emit(state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: e.toString(),
        ));
      }
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
