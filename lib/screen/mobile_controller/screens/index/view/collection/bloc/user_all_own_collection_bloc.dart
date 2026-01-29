import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
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
  UserAllOwnCollectionBloc(
    this._tokensService, {
    required this.addresses,
  }) : super(
          UserAllOwnCollectionState(
            addressStates: addresses.map((address) {
              return AddressState(
                address: address,
                assetTokens: [],
                state: AddressStateType.init,
                indexingStatus: null,
              );
            }).toList(),
          ),
        ) {
    on<FetchTokens>(_onFetchTokens);
    on<ClearDataEvent>(_onClearData);
    on<Reindex>(_onReindex);
    on<UpdateTokens>(_onUpdateTokens);
    on<PullStatus>(_onPullStatus);

    // On init, try to pull indexing status for all addresses in this bloc
    add(PullStatus());
  }

  final NftTokensService _tokensService;
  final List<String> addresses;

  Future<void> _onReindex(
    Reindex event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    if (addresses.isEmpty) return;

    try {
      log.info('[UserAllOwnCollectionBloc] Reindex addresses: $addresses');
      // Check if any of the addresses are already being reindexed
      final allIndexingAddresses = state.addressStates
          .where((state) => state.state == AddressStateType.indexStated)
          .map((state) => state.address)
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
      final updatedStates = state.addressStates.map((state) {
        if (newAddresses.contains(state.address)) {
          return AddressState(
              address: state.address,
              assetTokens: state.assetTokens,
              state: AddressStateType.indexStated,
              indexingStatus: null);
        }
        return state;
      }).toList();

      emit(state.copyWith(addressStates: updatedStates));

      int attempts = 0;
      final random = Random();

      while (true) {
        attempts++;
        if (attempts > 3) {
          log.info(
            '[UserAllOwnCollectionBloc] Reindex addresses: $newAddresses, attempt: $attempts, max attempts reached, will retry',
          );
          break;
        }
        log.info(
          '[UserAllOwnCollectionBloc] Reindex addresses: $newAddresses, attempt: $attempts',
        );

        try {
          add(FetchTokens(shouldUpdateLastRefreshedTime: false));
          final results = await _tokensService.reindexAddresses(newAddresses);

          final infos = results
              .map(
                (result) => AddressIndexingInfo(
                  address: result.address,
                  workflowId: result.workflowId,
                ),
              )
              .toList();
          await injector<UserDp1PlaylistService>().updateAddressIndexingInfo(
            infos: infos,
          );

          // Success, break out of retry loop
          break;
        } catch (e, st) {
          Sentry.captureException(e, stackTrace: st);
          log.info(
            '[UserAllOwnCollectionBloc] reindexAddresses error: $e, attempt: $attempts, will retry',
          );

          // Calculate delay: attempt * 2 seconds (max 100 seconds) + random(-2, +2) seconds
          final baseDelaySeconds = min(attempts * 2, 300);
          final randomVariation =
              random.nextInt(5) - 2; // Random between -2 and +2
          final delaySeconds = max(0, baseDelaySeconds + randomVariation);

          log.info(
            '[UserAllOwnCollectionBloc] Waiting ${delaySeconds}s before retry (base: ${baseDelaySeconds}s, variation: ${randomVariation}s)',
          );

          await Future<void>.delayed(Duration(seconds: delaySeconds));
        }
      }

      // After successfully submitting indexing jobs and storing workflowIds,
      // start pulling indexing status via dedicated PullStatus handler.
      add(PullStatus());
    } catch (e, st) {
      log.info('[UserAllOwnCollectionBloc] Reindex error: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
      // Update state to indexingIncomplete on error
      final updatedStates = state.addressStates.map((state) {
        return AddressState(
            address: state.address,
            assetTokens: state.assetTokens,
            state: AddressStateType.indexingIncomplete,
            indexingStatus: null);
      }).toList();
      emit(state.copyWith(
        status: UserAllOwnCollectionStatus.error,
        error: 'Something went wrong while indexing addresses.',
        addressStates: updatedStates,
      ));
    }
  }

  Future<void> _onFetchTokens(
    FetchTokens event,
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
            '[UserAllOwnCollectionBloc][_onFetchTokens] started for addresses: ${addresses.join(',')}, offset: ${event.offset}');
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
              '[UserAllOwnCollectionBloc][_onFetchTokens] not fetching, start fetching');
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
          final addressState =
              state.addressStates.getAddressState(addresses.first);
          final updatedStatesStart = state.addressStates.map((state) {
            if (addresses.contains(state.address)) {
              return AddressState(
                  address: state.address,
                  assetTokens: state.assetTokens,
                  state: AddressStateType.fetchingArtworks,
                  indexingStatus: addressState?.indexingStatus);
            }
            return state;
          }).toList();
          final newState = state.copyWith(
              addressStates: updatedStatesStart,
              status: UserAllOwnCollectionStatus.loading);
          emit(newState);
        }

        // get the stream
        final stream = await _tokensService.fetchTokensInIsolate(
            addresses, event.offset, null);

        final List<AssetToken> collected = [];

        _tokensStreamSubs[subKey] = stream.listen(
          (tokens) {
            log.info(
                '[${event.runtimeType}] Received ${tokens.length} tokens from stream for addresses: ${addresses.join(',')}');
            collected.addAll(tokens);
            injector<IndexerDatabaseAbstract>().insertTokens(
              tokens,
              addresses: addresses,
            );
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
              final updatedStates = state.addressStates.map((state) {
                if (addresses.contains(state.address)) {
                  return AddressState(
                      address: state.address,
                      assetTokens: state.assetTokens,
                      state: AddressStateType.fetchingArtworksFailed,
                      indexingStatus: null);
                }
                return state;
              }).toList();
              final newState = state.copyWith(
                  addressStates: updatedStates,
                  status: UserAllOwnCollectionStatus.error);
              emit(newState);
            }
            completer.safeCompleteError(error);
          },
          onDone: () async {
            // Stream done successfully (onDone only called when no error with cancelOnError: true)
            if (event.shouldUpdateAddressState) {
              final updatedStates =
                  await Future.wait(state.addressStates.map((state) async {
                if (addresses.contains(state.address)) {
                  // wait 3 seconds to wait for database to be updated
                  await Future<void>.delayed(const Duration(seconds: 3));
                  return AddressState(
                      address: state.address,
                      assetTokens: state.assetTokens,
                      state: AddressStateType.fetchingArtworksDone,
                      indexingStatus: state.indexingStatus);
                }
                return state;
              }).toList());
              final newState = state.copyWith(
                  addressStates: updatedStates,
                  status: UserAllOwnCollectionStatus.loaded);
              emit(newState);
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
            final updatedStates = state.addressStates.map((state) {
              if (addresses.contains(state.address)) {
                return AddressState(
                    address: state.address,
                    assetTokens: state.assetTokens,
                    state: AddressStateType.fetchingArtworksFailed,
                    indexingStatus: null);
              }
              return state;
            }).toList();
            emit(state.copyWith(addressStates: updatedStates));
          }
          rethrow;
        } finally {
          _tokensStreamSubs[subKey] = null;
          _activeCompleters[subKey] = null;
        }

        final addressMap = {
          for (final addr in addresses) addr: newLastUpdatedAt,
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

    emit(
      UserAllOwnCollectionState(
        addressStates: addresses.map((address) {
          return AddressState(
            address: address,
            assetTokens: [],
            state: AddressStateType.init,
            indexingStatus: null,
          );
        }).toList(),
      ),
    );
  }

  /// Helper method to update or create an AddressState for a given address
  List<AddressState> _updateOrCreateAddressState(
    String addressString,
    AddressStateType newState,
    AddressIndexingJobResponse? indexingStatus,
  ) {
    final existingStateIndex = state.addressStates.indexWhere(
      (state) => state.address == addressString,
    );

    if (existingStateIndex != -1) {
      // Update existing state
      return state.addressStates.map((state) {
        if (state.address == addressString) {
          return AddressState(
            address: state.address,
            assetTokens: state.assetTokens,
            state: newState,
            indexingStatus: indexingStatus,
          );
        }
        return state;
      }).toList();
    } else {
      // Create new state for address that doesn't exist yet
      final newAddressState = AddressState(
        address: addressString,
        assetTokens: [],
        state: newState,
        indexingStatus: indexingStatus,
      );
      return [...state.addressStates, newAddressState];
    }
  }

  Future<void> _onPullStatus(
    PullStatus event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      log.info(
        '[UserAllOwnCollectionBloc] PullStatus: checking indexing status for bloc addresses',
      );

      final addressToWorkflowId = <String, String>{};
      for (final address in addresses) {
        final info =
            injector<UserDp1PlaylistService>().getAddressIndexingInfo(address);
        if (info != null && info.workflowId.isNotEmpty) {
          addressToWorkflowId[address] = info.workflowId;
        }
      }

      if (addressToWorkflowId.isEmpty) {
        log.info(
          '[UserAllOwnCollectionBloc] PullStatus: no indexing info found for bloc addresses, skip checking status',
        );
        return;
      }

      await _tokensService.pullAddressesIndexingStatus(
        addressToWorkflowId: addressToWorkflowId,
        timeout: const Duration(hours: 1),
        onStatus: (status, address) async {
          log.info(
            '[PullStatus][$address] workflowId: ${addressToWorkflowId[address]} status: ${status.status.toJson()}, totalTokensIndexed: ${status.totalTokensIndexed}, totalTokensViewable: ${status.totalTokensViewable}',
          );

          // Update or create state with latest status
          final updatedStates = _updateOrCreateAddressState(
            address,
            AddressStateType.indexStated,
            status,
          );
          emit(state.copyWith(addressStates: updatedStates));

          if (status.status.isDone || status.status.isPaused) {
            log.info(
              '[UserAllOwnCollectionBloc] Address $address indexing completed via PullStatus',
            );
            // Fetch tokens after completion
            // if we already fetch tokens, don't fetch again
            final shouldForceFetch = await injector<UserDp1PlaylistService>()
                .shouldForceFetchTokenForAddress(address);
            if (shouldForceFetch) {
              log.info(
                '[UserAllOwnCollectionBloc] Address $address should force fetch tokens, start fetching',
              );
              add(FetchTokens(
                  shouldUpdateLastRefreshedTime: true,
                  shouldUpdateAddressState: true));
            } else {
              log.info(
                '[UserAllOwnCollectionBloc] Address $address already fetched tokens, skip fetching',
              );
              final updatedStates = _updateOrCreateAddressState(
                address,
                AddressStateType.fetchingArtworksDone,
                status,
              );
              emit(state.copyWith(addressStates: updatedStates));
            }

            return true;
          } else {
            // Still indexing, fetch tokens periodically
            // Calculate offset based on existing tokens
            final existingCount = await injector<IndexerDatabaseAbstract>()
                .countTokensByOwners(owners: addresses);
            log.info(
              '[UserAllOwnCollectionBloc][PullStatus] Still indexing, fetching with offset: $existingCount',
            );
            add(FetchTokens(
                offset: existingCount, shouldUpdateLastRefreshedTime: false));
            return false;
          }
        },
        onTimeout: (address) async {
          log.info(
            '[PullStatus] Timeout for address: $address',
          );
          await Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(
                'Timeout while checking indexing status for address: $address',
              ),
              level: SentryLevel.error,
              extra: {
                'stackTrace': StackTrace.current.toString(),
              },
              throwable:
                  'Timeout while checking indexing status for address: $address',
            ),
          );
          final updatedStates = _updateOrCreateAddressState(
              address, AddressStateType.getStatusFailed, null);
          emit(state.copyWith(addressStates: updatedStates));
          return true;
        },
        onError: (error, stackTrace, address) async {
          log.info(
            '[PullStatus] Error for address $address: $error',
          );
          await Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage(
                'Error while checking indexing status for address $address: $error',
              ),
              level: SentryLevel.error,
              extra: {
                'stackTrace': stackTrace.toString(),
              },
              throwable: error,
            ),
          );
          // final updatedStates = _updateOrCreateAddressState(
          //     address, AddressStateType.getStatusFailed, null);
          // emit(state.copyWith(addressStates: updatedStates));
          return false;
        },
      );
      log.info(
        '[UserAllOwnCollectionBloc] PullStatus: completed',
      );
    } catch (e, stackTrace) {
      log.warning(
        '[UserAllOwnCollectionBloc] PullStatus: error while checking indexing status: $e',
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  Future<void> _onUpdateTokens(
    UpdateTokens event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      log.info(
          '[UserAllOwnCollectionBloc][_onUpdateTokens] started with addresses: ${addresses.join(',')}');
      // Use event-specific key so we can run multiple concurrent update streams
      // for different address sets.
      final subKey = event.streamKey;

      if (addresses.isEmpty) {
        log.info(
            '[UserAllOwnCollectionBloc][_onUpdateTokens] addresses list cannot be empty');
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
          .getAddressOldestLastFetchTokenTime(addresses: addresses);

      final sinceIsoValues = lastFetchTokenTimeMap.values.nonNulls.toList();
      final oldestLastFetchTokenTime = sinceIsoValues.isEmpty
          ? null
          : sinceIsoValues.reduce((a, b) => a.compareTo(b) < 0 ? a : b);

      final addressAnchors = injector<UserDp1PlaylistService>()
          .getLastUpdateChangeAnchor(
              addresses: addresses,
              defaultAnchorBuilder: (address) =>
                  AddressAnchor(address: address, anchor: 0));

      // get stream from token service (updates from indexer changes)
      final stream = await _tokensService.updateTokensInIsolate(addressAnchors);

      _tokensStreamSubs[subKey] = stream.listen(
        (tokens) {
          log.info(
              '[${event.runtimeType}] Received ${tokens.length} tokens from stream for addresses: ${addresses.join(',')}');
          injector<IndexerDatabaseAbstract>().insertTokens(
            tokens,
            addresses: addresses,
          );
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
    log.info('[UserAllOwnCollectionBloc] closing bloc ${addresses.join(',')}');
    // Cancel all timers
    for (final timer in _workflowStatusTimers.values) {
      timer.cancel();
    }
    _workflowStatusTimers.clear();
    return super.close();
  }
}
