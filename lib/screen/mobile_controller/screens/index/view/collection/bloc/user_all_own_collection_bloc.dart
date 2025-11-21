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
      add(FetchTokensOfAddresses(
          addresses: owners, shouldUpdateLastRefreshedTime: true));
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
      // Check if any of the addresses are already being reindexed
      final allIndexingAddresses = state.addressStates
          .where((state) => state.state == AddressStateType.indexing)
          .map((state) => state.address.address)
          .toSet();
      final newAddresses = addresses
          .where((addr) => !allIndexingAddresses.contains(addr))
          .toList();

      if (newAddresses.isEmpty) {
        log.info(
            '[UserAllOwnCollectionBloc] All addresses $addresses are already being reindexed');
        return;
      }

      // Update state to indexing for new addresses
      final updatedStates = state.addressStates.updateStates(
        newAddresses,
        AddressStateType.indexing,
      );
      emit(state.copyWith(addressStates: updatedStates));

      // Track completed addresses from this event only
      final completedAddresses = <String>{};
      final maxAttempts = 5;
      int attempts = 0;

      while (attempts < maxAttempts) {
        attempts++;
        final addressesToReindex = addresses
            .where((addr) => !completedAddresses.contains(addr))
            .toList();
        log.info(
            '[UserAllOwnCollectionBloc] Reindex addresses: $addressesToReindex, attempt: $attempts');

        try {
          await _tokensService.reindexAddressesAndPullStatus(
            addresses: addressesToReindex,
            timeout: const Duration(days: 1),
            onBatchStart: (batchAddresses) async {
              // Update state to indexing when batch starts
              final updatedStates = state.addressStates.updateStates(
                batchAddresses,
                AddressStateType.indexing,
              );
              emit(state.copyWith(addressStates: updatedStates));
              log.info(
                  '[UserAllOwnCollectionBloc] Started indexing batch: $batchAddresses');
            },
            onStatus: (status, workflowId, runId, batchAddresses) async {
              log.info(
                  '[ReindexAddresses][${batchAddresses.join(',')}] status: ${status.toJson()}');
              if (status.isDone) {
                log.info(
                    'Pull workflow status done with status: ${status.toJson()}, workflowId: $workflowId, runId: $runId');
                if (status.isSuccess) {
                  // Mark addresses from this batch as completed
                  completedAddresses.addAll(batchAddresses);
                  log.info(
                      '[UserAllOwnCollectionBloc] Batch $batchAddresses completed successfully. Completed addresses: ${completedAddresses.length}/${addresses.length}');
                  // Update state to gettingArtworks
                  final updatedStates = state.addressStates.updateStates(
                    batchAddresses,
                    AddressStateType.indexingDone,
                  );
                  await injector<UserDp1PlaylistService>()
                      .updateAddressLastIndexTime(
                    addresses: {
                      for (final addr in batchAddresses) addr: DateTime.now(),
                    },
                  );
                  emit(state.copyWith(addressStates: updatedStates));
                }
              } else {
                // Still indexing, fetch tokens
                add(FetchTokensOfAddresses(addresses: batchAddresses));
              }
              add(
                WorkflowStatusTick(
                  operationId: batchAddresses.join(','),
                  addresses: batchAddresses,
                  workflowId: workflowId,
                  runId: runId,
                  status: status,
                ),
              );
              // Return true to complete if status is done
              return status.isDone;
            },
            onTimeout: (batchAddresses) {
              log.info('[ReindexAddresses] Timeout for batch: $batchAddresses');
              Sentry.captureEvent(SentryEvent(
                message: SentryMessage('Timeout for batch: $batchAddresses'),
                level: SentryLevel.error,
                extra: {
                  'stackTrace': StackTrace.current.toString(),
                },
                throwable: 'Timeout for batch: $batchAddresses',
              ));
              // Update state to indexingIncomplete on timeout
              // final updatedStates = state.addressStates.updateStates(
              //   batchAddresses,
              //   AddressStateType.indexingIncomplete,
              // );
              // emit(state.copyWith(addressStates: updatedStates));
            },
            onError: (error, stackTrace, batchAddresses) {
              // Keep polling despite transient errors
              log.info(
                  '[ReindexAddresses] Error for batch $batchAddresses: $error');
              unawaited(Sentry.captureEvent(SentryEvent(
                message:
                    SentryMessage('Error for batch $batchAddresses: $error'),
                level: SentryLevel.error,
                extra: {
                  'stackTrace': stackTrace.toString(),
                },
                throwable: error,
              )));
            },
          );
        } catch (e, st) {
          Sentry.captureException(e, stackTrace: st);
        }

        // Wait a bit for events to be processed
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Also check completed addresses to ensure we have all
        final allCompleted = completedAddresses.length == addresses.length;

        if (allCompleted) {
          log.info(
              '[UserAllOwnCollectionBloc] All addresses from this event have been indexed. Completed: ${completedAddresses.length}/${addresses.length}');
          break;
        } else {
          log.info(
              '[UserAllOwnCollectionBloc] Completed addresses: ${completedAddresses.join(',')}. Waiting for 10 seconds');
          await Future<void>.delayed(const Duration(seconds: 10));
        }
      }

      // after all attempts, if some addresses are not completed, mark them as failed
      final failedAddresses = addresses
          .where((addr) => !completedAddresses.contains(addr))
          .toList();
      if (failedAddresses.isNotEmpty) {
        log.info(
            '[UserAllOwnCollectionBloc] Failed addresses: ${failedAddresses.join(',')}. Marking as incomplete');
        final updatedStates = state.addressStates.updateStates(
          failedAddresses,
          AddressStateType.indexingIncomplete,
        );
        emit(state.copyWith(addressStates: updatedStates));
      }
    } catch (e, st) {
      log.info('[UserAllOwnCollectionBloc] Reindex error: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
      // Update state to indexingIncomplete on error
      final updatedStates = state.addressStates.updateStates(
        addresses,
        AddressStateType.indexingIncomplete,
      );
      emit(state.copyWith(
        status: UserAllOwnCollectionStatus.error,
        error: 'Something went wrong while indexing addresses.',
        addressStates: updatedStates,
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

      DateTime newLastUpdatedAt = DateTime.now();

      final prevCompleter = _activeCompleters[subType];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new fetch load');
      }
      final completer = Completer<void>();
      _activeCompleters[subType] = completer;

      // Update state to fetchingArtworks when starting to fetch
      final updatedStatesStart = state.addressStates.updateStates(
        event.addresses,
        AddressStateType.fetchingArtworks,
      );
      emit(state.copyWith(
        addressStates: updatedStatesStart,
        status: UserAllOwnCollectionStatus.loading,
      ));

      // get the stream
      final stream = await _tokensService.fetchTokensInIsolate(event.addresses);

      final List<AssetToken> collected = [];

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info(
              '[${event.runtimeType}] Received ${tokens.length} tokens from stream for addresses: ${event.addresses.join(',')}');
          collected.addAll(tokens);
          emit(state.copyWith(
            status: UserAllOwnCollectionStatus.loaded,
          ));
          if (tokens.isNotEmpty) {
            add(ReloadAssetTokensFromIndexerDatabase());
          }
          final updatedAts =
              tokens.map((token) => token.updatedAt).nonNulls.toList();
          if (updatedAts.isNotEmpty) {
            final lastUpdated =
                updatedAts.reduce((a, b) => a.isAfter(b) ? a : b);
            newLastUpdatedAt = lastUpdated;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          Sentry.captureException('Failed to refresh asset tokens: $error');
          // Update state to gettingArtworksFailed on error
          final updatedStates = state.addressStates.updateStates(
            event.addresses,
            AddressStateType.fetchingArtworksFailed,
          );
          emit(state.copyWith(addressStates: updatedStates));
          _activeCompleters[subType]?.completeError(error);
        },
        onDone: () {
          // Update state to artworksReady when done
          final updatedStates = state.addressStates.updateStates(
            event.addresses,
            AddressStateType.fetchingArtworksDone,
          );
          emit(state.copyWith(
            addressStates: updatedStates,
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

      if (event.shouldUpdateLastRefreshedTime) {
        // update the last updated at
        await injector<UserDp1PlaylistService>()
            .updateAddressLastFetchTokenTime(
          addresses: addressMap,
        );
      }

      add(ReloadAssetTokensFromIndexerDatabase());
      event.onDone?.call();
    } catch (e) {
      log.info('[${event.runtimeType}] error $e');
      Sentry.captureException('Failed to refresh asset tokens: $e');
      event.onError?.call(e, StackTrace.current);
    }
    log.info('[${event.runtimeType}] completed');
  }

  Future<void> _onReloadAssetTokensFromIndexerDatabase(
    ReloadAssetTokensFromIndexerDatabase event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    final owners = _dynamicQuery?.params.owners;
    if (owners == null) {
      emit(state.copyWith(addressStates: []));
      return;
    }
    final assetTokenGroupByAddress = injector<IndexerDatabaseAbstract>()
        .getGroupAssetTokensByOwnersGroupByAddress(
      owners: _dynamicQuery!.params.owners,
    );

    // Preserve existing states when reloading
    final existingStatesMap = {
      for (final addrState in state.addressStates)
        addrState.address.address: addrState.state
    };

    emit(
      state.copyWith(
        addressStates: assetTokenGroupByAddress
            .map(
              (e) => AddressState(
                address: e.address,
                assetTokens: e.assetTokens,
                state: existingStatesMap[e.address.address] ??
                    AddressStateType.fetchingArtworksDone,
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
    final opId = event.operationId;
    if (event.status.isDone) {
      _workflowStatusTimers[opId]?.cancel();
      _workflowStatusTimers.remove(opId);

      try {
        if (event.status.isSuccess) {
          // Update state to gettingArtworks before fetching
          final updatedStates = state.addressStates.updateStates(
            event.addresses,
            AddressStateType.fetchingArtworks,
          );
          emit(state.copyWith(addressStates: updatedStates));

          final completer = Completer<void>();
          add(
            FetchTokensOfAddresses(
              addresses: event.addresses,
              shouldUpdateLastRefreshedTime: true,
              onDone: () {
                completer.complete();
              },
              onError: (error, stackTrace) {
                completer.completeError(error);
              },
            ),
          );
          await completer.future;
        } else if (event.status.isRunning) {
          // Still running, keep indexing state
          add(FetchTokensOfAddresses(
              addresses: event.addresses,
              shouldUpdateLastRefreshedTime: false));
        } else if (event.status == WorkflowExecutionStatus.timedOut) {
          // Update state to indexingIncomplete on timeout
          final updatedStates = state.addressStates.updateStates(
            event.addresses,
            AddressStateType.indexingIncomplete,
          );
          emit(state.copyWith(addressStates: updatedStates));
        } else {
          // Update state to indexingIncomplete on failure
          final updatedStates = state.addressStates.updateStates(
            event.addresses,
            AddressStateType.indexingIncomplete,
          );
          emit(state.copyWith(
            addressStates: updatedStates,
          ));
        }
      } catch (e, stackTrace) {
        log.info('[UserAllOwnCollectionBloc][_onWorkflowStatusTick] error $e');
        Sentry.captureException('Failed to fetch tokens of addresses: $e',
            stackTrace: stackTrace);
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

      final lastUpdateChangeAt =
          injector<UserDp1PlaylistService>().getLastUpdateChangeAt() ??
              DateTime(1970);

      final addressMap = {
        for (final addr in event.addresses) addr: lastUpdateChangeAt,
      };

      // get stream from token service (updates from indexer changes)
      final stream = await _tokensService.updateTokensInIsolate(addressMap);

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info(
              '[${event.runtimeType}] Received ${tokens.length} tokens from stream for addresses: ${event.addresses.join(',')}');
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
