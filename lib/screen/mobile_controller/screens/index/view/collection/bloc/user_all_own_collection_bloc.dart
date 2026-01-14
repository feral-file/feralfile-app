import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/completer_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

part 'user_all_own_collection_event.dart';
part 'user_all_own_collection_state.dart';

class UserAllOwnCollectionBloc
    extends Bloc<UserAllOwnCollectionEvent, UserAllOwnCollectionState> {
  // Track active stream subscriptions per logical operation key.
  // The key is provided by each event via UserAllOwnCollectionEvent.streamKey,
  // allowing multiple concurrent operations of the same event type with
  // different parameters (e.g. different address sets).
  final Map<String, StreamSubscription<List<AssetToken>>?> _tokensStreamSubs =
      {};
  final Map<String, Completer<void>?> _activeCompleters = {};
  final Map<String, Timer> _workflowStatusTimers = {};
  UserAllOwnCollectionBloc(this._tokensService)
      : super(const UserAllOwnCollectionState()) {
    on<FetchTokensOfAddresses>(_onFetchTokensOfAddresses);
    on<ClearDataEvent>(_onClearData);
    on<ReindexAddresses>(_onReindexAddresses);
    on<WorkflowStatusTick>(_onWorkflowStatusTick);
    on<UpdateTokensOfAddresses>(_onUpdateTokensOfAddresses);
  }

  final NftTokensService _tokensService;

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
      Object? error = null;

      while (attempts < maxAttempts) {
        attempts++;
        error = null;
        final addressesToReindex = addresses
            .where((addr) => !completedAddresses.contains(addr))
            .toList();
        log.info(
            '[UserAllOwnCollectionBloc] Reindex addresses: $addressesToReindex, attempt: $attempts');

        try {
          add(FetchTokensOfAddresses(
              addresses: addressesToReindex, shouldUpdateAddressState: false));
          await _tokensService.reindexAddressesAndPullStatus(
            addresses: addressesToReindex,
            timeout: const Duration(hours: 1),
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
                add(FetchTokensOfAddresses(
                    addresses: batchAddresses,
                    shouldUpdateAddressState: false));
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
              error = Exception('Timeout for batch: $batchAddresses');
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
              error = error;
            },
          );
        } catch (e, st) {
          Sentry.captureException(e, stackTrace: st);
          error = e;
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
    final maxRetryAttempts = 3;
    int retryAttempts = 0;
    Object? error = null;
    while (retryAttempts < maxRetryAttempts) {
      retryAttempts++;
      error = null;
      try {
        log.info(
            '[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] started');
        // Use event-specific key so we can run multiple concurrent operations
        // for different address sets, while still deduplicating identical ones.
        final subKey = event.streamKey;

        // If the same operation key is already being processed, ignore this event
        final isProcessing = _tokensStreamSubs[subKey] != null ||
            _activeCompleters[subKey]?.isCompleted == false;
        if (isProcessing) {
          // log.info(
          //     '[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] fetching, ignore');
          // return;
        } else {
          log.info(
              '[UserAllOwnCollectionBloc][_onFetchTokensOfAddresses] not fetching, start fetching');
        }
        // cancel the previous stream
        await _tokensStreamSubs[subKey]?.cancel();
        _tokensStreamSubs[subKey] = null;

        DateTime newLastUpdatedAt = DateTime.now();

        final prevCompleter = _activeCompleters[subKey];
        if (prevCompleter?.isCompleted == false) {
          prevCompleter?.complete('Cancelled by new fetch load');
        }
        final completer = Completer<void>();
        _activeCompleters[subKey] = completer;

        // Update state to fetchingArtworks when starting to fetch
        if (event.shouldUpdateAddressState) {
          final updatedStatesStart = state.addressStates.updateStates(
            event.addresses,
            AddressStateType.fetchingArtworks,
          );
          emit(state.copyWith(
            addressStates: updatedStatesStart,
            status: UserAllOwnCollectionStatus.loading,
          ));
        }

        // get the stream
        final stream = await _tokensService.fetchTokensInIsolate(
            event.addresses, null, null);

        final List<AssetToken> collected = [];

        _tokensStreamSubs[subKey] = stream.listen(
          (tokens) {
            log.info(
                '[${event.runtimeType}] Received ${tokens.length} tokens from stream for addresses: ${event.addresses.join(',')}');
            collected.addAll(tokens);
            injector<IndexerDatabaseAbstract>().insertTokens(tokens);
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
            Sentry.captureException(
                'Failed to fetch asset tokens: $error attempt: $retryAttempts / $maxRetryAttempts');
            final isLastAttempt = retryAttempts == maxRetryAttempts;
            // Update state to gettingArtworksFailed on error
            if (isLastAttempt && event.shouldUpdateAddressState) {
              final updatedStates = state.addressStates.updateStates(
                event.addresses,
                AddressStateType.fetchingArtworksFailed,
              );
              emit(state.copyWith(addressStates: updatedStates));
            }
            completer.safeCompleteError(error);
          },
          onDone: () {
            // Stream done successfully (onDone only called when no error with cancelOnError: true)
            if (event.shouldUpdateAddressState) {
              final updatedStates = state.addressStates.updateStates(
                event.addresses,
                AddressStateType.fetchingArtworksDone,
              );
              emit(state.copyWith(
                addressStates: updatedStates,
                status: UserAllOwnCollectionStatus.loaded,
              ));
            }
            log.info(
                '[${event.runtimeType}] Stream done successfully with total ${collected.length} tokens');
            completer.safeComplete(null);
          },
          cancelOnError: true,
        );

        try {
          await completer.future;
        } catch (e) {
          // Stream completed with error
          log.info('[${event.runtimeType}] Stream completed with error: $e');
          final isLastAttempt = retryAttempts == maxRetryAttempts;
          if (isLastAttempt && event.shouldUpdateAddressState) {
            final updatedStates = state.addressStates.updateStates(
              event.addresses,
              AddressStateType.fetchingArtworksFailed,
            );
            emit(state.copyWith(addressStates: updatedStates));
          }
          rethrow;
        } finally {
          _tokensStreamSubs[subKey] = null;
          _activeCompleters[subKey] = null;
        }

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

        // add(ReloadAssetTokensFromIndexerDatabase());
      } catch (e) {
        error = e;
        log.info('[${event.runtimeType}] error $e');
        Sentry.captureException('Failed to refresh asset tokens: $e');
      }
      log.info('[${event.runtimeType}] completed');
      if (error == null) {
        break;
      } else {
        log.info('[${event.runtimeType}] error $error, retrying...');
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }
    if (error != null) {
      event.onError?.call(error, StackTrace.current);
    } else {
      event.onDone?.call();
    }
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

    emit(const UserAllOwnCollectionState());
  }

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
          '[UserAllOwnCollectionBloc][_onUpdateTokensOfAddresses] started with addresses: ${event.addresses.join(',')}');
      // Use event-specific key so we can run multiple concurrent update streams
      // for different address sets.
      final subKey = event.streamKey;

      if (event.addresses.isEmpty) {
        log.info(
            '[UserAllOwnCollectionBloc][_onUpdateTokensOfAddresses] addresses list cannot be empty');
        return;
      }

      // cancel previous stream for this subtype
      await _tokensStreamSubs[subKey]?.cancel();
      _tokensStreamSubs[subKey] = null;

      final completer = Completer<void>();
      final prevCompleter = _activeCompleters[subKey];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new update tokens request');
      }
      _activeCompleters[subKey] = completer;

      final lastFetchTokenTimeMap = injector<UserDp1PlaylistService>()
          .getAddressOldestLastFetchTokenTime(addresses: event.addresses);

      final sinceIsoValues = lastFetchTokenTimeMap.values.nonNulls.toList();
      final oldestLastFetchTokenTime = sinceIsoValues.isEmpty
          ? null
          : sinceIsoValues.reduce((a, b) => a.compareTo(b) < 0 ? a : b);

      final addressAnchors = injector<UserDp1PlaylistService>()
          .getLastUpdateChangeAnchor(
              addresses: event.addresses,
              defaultAnchorBuilder: (address) =>
                  AddressAnchor(address: address, anchor: 0));

      // get stream from token service (updates from indexer changes)
      final stream = await _tokensService.updateTokensInIsolate(addressAnchors);

      _tokensStreamSubs[subKey] = stream.listen(
        (tokens) {
          log.info(
              '[${event.runtimeType}] Received ${tokens.length} tokens from stream for addresses: ${event.addresses.join(',')}');
          injector<IndexerDatabaseAbstract>().insertTokens(tokens);
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          Sentry.captureException('Failed to update asset tokens: $error');
          _activeCompleters[subKey]?.completeError(error);
        },
        onDone: () async {
          _activeCompleters[subKey]?.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
      _tokensStreamSubs[subKey] = null;
      // add(ReloadAssetTokensFromIndexerDatabase());
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
