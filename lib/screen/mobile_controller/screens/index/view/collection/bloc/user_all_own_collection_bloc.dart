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
    on<RefreshAssetTokens>(_onRefreshLoad);
    on<UpdateDynamicQueryEvent>(_onUpdateDynamicQuery);
    on<ReloadAssetTokensFromIndexerDatabase>(
        _onReloadAssetTokensFromIndexerDatabase);
    on<ClearDataEvent>(_onClearData);
    on<PollWorkflowStatus>(_onPollWorkflowStatus);
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
      add(RefreshAssetTokens());
    } else {
      add(RefreshAssetTokens(shouldEmitLoading: true));
      add(ReloadAssetTokensFromIndexerDatabase());
    }
  }

  Future<void> _onRefreshLoad(
    RefreshAssetTokens event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      log.info('[UserAllOwnCollectionBloc][_onRefreshLoad] started');
      // If the same type is already being processed, ignore this event
      final subType = event.runtimeType;
      if (isRefreshAssetTokenFromDynamicQueryProcessing) {
        log.info(
            '[UserAllOwnCollectionBloc][_onRefreshLoad] refreshing, ignore');
        return;
      } else {
        log.info(
            '[UserAllOwnCollectionBloc][_onRefreshLoad] not refreshing, start refreshing');
      }
      if (event.shouldEmitLoading) {
        log.info(
            '[UserAllOwnCollectionBloc][_onRefreshLoad] emit loading state');
        emit(state.copyWith(status: UserAllOwnCollectionStatus.loading));
      }
      // cancel the previous stream
      await _tokensStreamSubs[subType]?.cancel();
      _tokensStreamSubs[subType] = null;

      // get the owners
      final addresses = injector<AddressService>().getAllAddresses();
      final dynamicQueryOwners = _dynamicQuery?.params.owners;

      final owners = [
        ...addresses,
        if (dynamicQueryOwners != null) ...dynamicQueryOwners
      ].toSet().toList();

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
      final stream = await _tokensService.refreshTokensInIsolate(
        {lastUpdatedAt.millisecondsSinceEpoch: owners},
        // owners,
        // pageSize: 20,
        // lastUpdatedAt: lastUpdatedAt,
      );

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

      // update the last updated at
      await injector<UserDp1PlaylistService>().updateAddressLastRefreshedTime(
        addresses: owners,
        dateTime: newLastUpdatedAt,
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
      _tokensStreamSubs[RefreshAssetTokens] != null ||
      _activeCompleters[RefreshAssetTokens]?.isCompleted == false;

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

    // Poll workflow status every 5 seconds
    final timer = Timer.periodic(pollInterval, (timer) async {
      try {
        // Check timeout
        if (DateTime.now().difference(startTime) >= timeoutDuration) {
          timer.cancel();
          _workflowStatusTimers.remove(operationKey);
          log.info(
            '[PollWorkflowStatus] Timeout after 10 minutes, stopping poll for workflowId: ${event.workflowId}, runId: ${event.runId}',
          );

          // Remove operation from state (just stop polling, don't emit error)
          final finalOperations =
              List<IndexingOperation>.from(state.indexingOperations);
          finalOperations.removeWhere((op) => op.key == operationKey);

          emit(state.copyWith(
            indexingOperations: finalOperations,
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

        // Check if workflow is done
        if (workflowStatus.status.isDone) {
          timer.cancel();
          _workflowStatusTimers.remove(operationKey);
          log.info(
            '[PollWorkflowStatus] Workflow done with status: ${workflowStatus.status.toJson()}',
          );

          // Remove operation from state
          final finalOperations =
              List<IndexingOperation>.from(state.indexingOperations);
          finalOperations.removeWhere((op) => op.key == operationKey);

          // If completed successfully, refresh tokens
          if (workflowStatus.status.isSuccess) {
            emit(state.copyWith(
              indexingOperations: finalOperations,
            ));
            add(RefreshAssetTokens(shouldEmitLoading: true));
          } else {
            emit(state.copyWith(
              status: UserAllOwnCollectionStatus.error,
              error: 'Workflow ${workflowStatus.status.toJson().toLowerCase()}',
              indexingOperations: finalOperations,
            ));
          }
        }
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
