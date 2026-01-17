//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_changes.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/list_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/timer_ext.dart';
import 'package:collection/collection.dart';
import 'package:get_it/get_it.dart';
import 'package:sentry/sentry.dart';
import 'package:uuid/uuid.dart';

abstract class NftTokensService {
  Future<List<AssetToken>> getManualTokens({
    required List<String> cids,
    bool shouldCallIndexer = true,
  });

  Future<List<AssetToken>> fetchManualTokens({
    required List<String> cids,
  });

  Future<Stream<List<AssetToken>>> fetchTokensInIsolate(
    List<String> addresses,
    int? offset,
    int? total,
  );

  Future<List<AddressIndexingResult>> reindexAddresses(List<String> addresses);

  Future<TriggerIndexingResult> reindexTokensByCids(
    List<String> tokenCids,
  );

  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    List<AddressAnchor> addressAnchors,
  );

  /// Pull address indexing status for existing workflows (no new indexing).
  ///
  /// [addressToWorkflowId] - Map of address to existing workflowId.
  /// [timeout] - Max duration to keep polling for each address.
  /// [onStatus] - Callback invoked on each status update. Return true to stop
  /// polling for that address, false to continue.
  /// [onTimeout] - Callback invoked when timeout is reached for an address.
  /// [onError] - Callback invoked when a polling error occurs.
  Future<void> pullAddressesIndexingStatus({
    required Map<String, String> addressToWorkflowId,
    required Duration timeout,
    required FutureOr<bool> Function(
            AddressIndexingJobResponse status, String address)
        onStatus,
    required FutureOr<bool> Function(String address) onTimeout,
    required FutureOr<bool> Function(
            Object error, StackTrace stackTrace, String address)
        onError,
  });

  Future<void> reindexByCidsAndPullStatus({
    required List<String> tokenCids,
    required Duration timeout,
    required FutureOr<bool> Function(
            WorkflowExecutionStatus status, String workflowId, String runId)
        onStatus,
    required FutureOr<void> Function() onTimeout,
    required FutureOr<void> Function(Object error, StackTrace stackTrace)
        onError,
  });

  Future<void> purgeCachedGallery();

  /// Pause all polling timers when app goes to background
  void pausePollingTimers();

  /// Resume all polling timers when app comes to foreground
  void resumePollingTimers();
}

final _isolateScopeInjector = GetIt.asNewInstance();

class NftTokensServiceImpl extends NftTokensService {
  NftTokensServiceImpl(
    this._indexerUrl,
    this._database,
    this._configurationService, {
    String? indexerAPIKey,
  }) : _indexerAPIKey = indexerAPIKey ?? Environment.indexerAPIKey {
    final indexerClient = IndexerClient(
      _indexerUrl,
      indexerAPIKey: _indexerAPIKey,
      httpTimeout: const Duration(seconds: 30),
    );
    _indexerService = NftIndexerService(indexerClient);
  }

  final String _indexerUrl;
  final String _indexerAPIKey;
  late NftIndexerService _indexerService;
  final IndexerDatabaseAbstract _database;
  final NftCollectionPrefs _configurationService;

  static const FETCH_ALL_TOKENS = 'FETCH_ALL_TOKENS';
  static const REINDEX_ADDRESSES_LIST = 'REINDEX_ADDRESSES_LIST';
  static const REINDEX_TOKENS = 'REINDEX_TOKENS';
  static const UPDATE_TOKENS_IN_ISOLATE = 'UPDATE_TOKENS_IN_ISOLATE';
  static const FETCH_MANUAL_TOKENS = 'FETCH_MANUAL_TOKENS';

  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  var _isolateReady = Completer<void>();
  // Map of UUID to stream controller for deduplication
  final Map<String, StreamController<List<AssetToken>>> _fetchTokensWorkers =
      {};

  // Store both old and new result types for backward compatibility
  final Map<String, Completer<List<AddressIndexingResult>>>
      _reindexAddressesCompleters = {};
  final Map<String, Completer<TriggerIndexingResult>> _indexTokensCompleters =
      {};
  final Map<String, StreamController<List<AssetToken>>> _streamControllers = {};
  // Track manual token fetch requests by UUID
  final Map<String, Completer<List<AssetToken>>> _fetchManualTokensCompleters =
      {};
  // Track running reindex operations by token CIDs key (deduplication)
  final Map<String, Completer<void>> _reindexCidsAndPullCompleters = {};
  final Map<String, Timer> _reindexCidsAndPullTimers = {};
  // Flag to pause polling when app is in background
  bool _isPollingPaused = false;

  Future<void> get isolateReady => _isolateReady.future;

  Future<void> start() async {
    if (_sendPort != null) return;

    _receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    _receivePort!.listen(_handleMessageInMain);

    _isolate = await Isolate.spawn(
      _isolateEntry,
      [
        _receivePort!.sendPort,
        _indexerUrl,
        _indexerAPIKey,
      ],
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    errorPort.listen((message) {
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Error in isolate: $message'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': StackTrace.current.toString(),
        },
        throwable: message,
      ));
    });
    exitPort.listen((message) {
      NftCollection.logger.info('[TokensService][exit] $message');
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Exit isolate: $message'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': StackTrace.current.toString(),
        },
        throwable: message,
      ));
    });
  }

  Future<void> startIsolateOrWait() async {
    NftCollection.logger.info('[FeedService] startIsolateOrWait');
    if (_sendPort == null) {
      await start();
      await isolateReady;
      //
    } else if (!_isolateReady.isCompleted) {
      await isolateReady;
    }
  }

  void disposeIsolate() {
    NftCollection.logger.info('[TokensService][disposeIsolate] Start');
    // Close all fetch tokens workers
    for (final controller in _fetchTokensWorkers.values) {
      controller.close();
    }
    _fetchTokensWorkers.clear();
    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    for (final completer in _reindexCidsAndPullCompleters.values) {
      completer.completeError(Exception('Isolate disposed'));
    }
    _reindexCidsAndPullCompleters.clear();
    // Cancel all reindex CIDs and pull timers
    for (final timer in _reindexCidsAndPullTimers.values) {
      timer.cancel();
    }
    _reindexCidsAndPullTimers.clear();

    for (final completer in _reindexCidsAndPullCompleters.values) {
      completer.completeError(Exception('Isolate disposed'));
    }
    _reindexCidsAndPullCompleters.clear();
    // Cancel all manual token fetch completers
    for (final completer in _fetchManualTokensCompleters.values) {
      completer.completeError(Exception('Isolate disposed'));
    }
    _fetchManualTokensCompleters.clear();
    _isolate?.kill();
    _isolateSendPort = null;
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _isolateReady = Completer<void>();
    NftCollection.logger.info('[TokensService][disposeIsolate] Done');
  }

  @override
  Future<void> purgeCachedGallery() async {
    disposeIsolate();
    await injector<ConfigurationService>().clearAddressLastFetchTokenTime();

    await _configurationService.setDidSyncAddress(false);
    _database.clearAll();
  }

  @override
  void pausePollingTimers() {
    _isPollingPaused = true;
    NftCollection.logger
        .info('[TokensService] Pausing polling timers (app in background)');
  }

  @override
  void resumePollingTimers() {
    _isPollingPaused = false;
    NftCollection.logger
        .info('[TokensService] Resuming polling timers (app in foreground)');
  }

  @override
  Future<Stream<List<AssetToken>>> fetchTokensInIsolate(
    List<String> addresses,
    int? offset,
    int? total,
  ) async {
    // Generate unique UUID for this request
    final uuid = const Uuid().v4();
    NftCollection.logger.info(
        '[fetchTokensInIsolate] Creating new request with UUID: $uuid for addresses: $addresses');

    await startIsolateOrWait();

    // Create new broadcast stream controller for this request
    // Use broadcast stream to allow multiple listeners (multiple bloc instances)
    final worker = StreamController<List<AssetToken>>.broadcast();
    _fetchTokensWorkers[uuid] = worker;

    _sendPort?.send([
      FETCH_ALL_TOKENS,
      uuid,
      addresses,
      offset,
      total,
    ]);

    NftCollection.logger.info(
        '[FETCH_ALL_TOKENS][start] UUID: $uuid, addresses: $addresses, offset: $offset, total: $total');
    worker.stream.listen((tokens) {
      NftCollection.logger.info(
          '[fetchTokensInIsolate] Received ${tokens.length} tokens from stream for UUID: $uuid addresses: ${addresses.join(',')}');
    }, onError: (Object error, StackTrace stackTrace) {
      NftCollection.logger.warning(
          '[fetchTokensInIsolate] Error for addresses: ${addresses.join(',')} UUID $uuid: $error');
    }, onDone: () {
      NftCollection.logger.info(
          '[fetchTokensInIsolate] Stream done for addresses: ${addresses.join(',')} UUID: $uuid');
    });

    return worker.stream;
  }

  @override
  Future<List<AddressIndexingResult>> reindexAddresses(
      List<String> addresses) async {
    if (addresses.isEmpty) {
      throw ArgumentError('Addresses list cannot be empty');
    }

    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final completer = Completer<List<AddressIndexingResult>>();
    _reindexAddressesCompleters[uuid] = completer;

    if (_sendPort == null) {
      throw Exception('Isolate not started');
    }

    // Use new API via isolate - call indexAddressesList
    _sendPort?.send([REINDEX_ADDRESSES_LIST, uuid, addresses]);

    NftCollection.logger.fine('[reindexAddresses][start] $addresses');

    try {
      // Wait for result from isolate
      final results = await completer.future;

      NftCollection.logger.fine(
          '[reindexAddresses][complete] processed ${addresses.length} addresses, got ${results.length} results');
      return results;
    } catch (e, stackTrace) {
      NftCollection.logger.warning('[reindexAddresses] Error: $e');
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Error reindexing addresses: $e'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': stackTrace.toString(),
        },
        throwable: e,
      )));
      rethrow;
    }
  }

  @override
  Future<TriggerIndexingResult> reindexTokensByCids(
      List<String> tokenCids) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final completer = Completer<TriggerIndexingResult>();
    _indexTokensCompleters[uuid] = completer;

    _sendPort?.send([REINDEX_TOKENS, uuid, tokenCids]);

    NftCollection.logger.fine('[reindexTokensByCids][start] $tokenCids');
    return completer.future.timeout(const Duration(seconds: 30));
  }

  @override
  Future<void> pullAddressesIndexingStatus({
    required Map<String, String> addressToWorkflowId,
    required Duration timeout,
    required FutureOr<bool> Function(
            AddressIndexingJobResponse status, String address)
        onStatus,
    required FutureOr<bool> Function(String address) onTimeout,
    required FutureOr<bool> Function(
            Object error, StackTrace stackTrace, String address)
        onError,
  }) async {
    if (addressToWorkflowId.isEmpty) return;

    // Reuse common polling logic to pull indexing status
    await _pollAddressesIndexingStatus(
      addressToWorkflowId: addressToWorkflowId,
      timeout: timeout,
      onStatus: onStatus,
      onTimeout: onTimeout,
      onError: onError,
      logPrefix: 'pullAddressesIndexingStatus',
    );
  }

  Future<void> _pollAddressesIndexingStatus({
    required Map<String, String> addressToWorkflowId,
    required Duration timeout,
    required FutureOr<bool> Function(
            AddressIndexingJobResponse status, String address)
        onStatus,
    required FutureOr<bool> Function(String address) onTimeout,
    required FutureOr<bool> Function(
            Object error, StackTrace stackTrace, String address)
        onError,
    required String logPrefix,
  }) async {
    if (addressToWorkflowId.isEmpty) {
      return;
    }

    // Track completed addresses
    final completedAddresses = <String>{};
    // Track timers per address
    final addressTimers = <String, Timer>{};
    // Track completers per address
    final addressCompleters = <String, Completer<void>>{};

    // Poll status for each address individually
    for (final entry in addressToWorkflowId.entries) {
      final address = entry.key;
      final workflowId = entry.value;
      final addressKey = address;

      // Skip if already completed
      if (completedAddresses.contains(address)) continue;

      // Cancel previous timer if any
      addressTimers[addressKey]?.cancel();

      final startedAt = DateTime.now();
      final addressCompleter = Completer<void>();
      addressCompleters[addressKey] = addressCompleter;

      addressTimers[addressKey] = TimerExtension.periodicAndRunNow(
        // random duration between 5 and 10 seconds
        Duration(seconds: Random().nextInt(5) + 15),
        (timer) async {
          try {
            // Skip polling if paused (app is in background)
            if (_isPollingPaused) {
              return;
            }

            // Skip if already completed
            if (completedAddresses.contains(address)) {
              timer.cancel();
              addressTimers.remove(addressKey);
              if (!addressCompleter.isCompleted) {
                addressCompleter.complete();
              }
              return;
            }

            // Check timeout
            if (DateTime.now().difference(startedAt) > timeout) {
              timer.cancel();
              addressTimers.remove(addressKey);
              final shouldComplete = await onTimeout(address);
              if (shouldComplete) {
                completedAddresses.add(address);
                timer.cancel();
                addressTimers.remove(addressKey);
                if (!addressCompleter.isCompleted) {
                  addressCompleter.complete();
                }
              }
              return;
            }

            // Get address indexing job status (no runId needed)
            final status =
                await _indexerService.getAddressIndexingJobStatus(workflowId);
            NftCollection.logger.info(
              '[$logPrefix][$address] status: ${status.status.toJson()}, '
              'totalTokensIndexed: ${status.totalTokensIndexed}, totalTokensViewable: ${status.totalTokensViewable}',
            );

            // Call onStatus callback - if returns true, complete and cleanup
            final shouldComplete = await onStatus(status, address);
            if (shouldComplete) {
              completedAddresses.add(address);
              timer.cancel();
              addressTimers.remove(addressKey);
              if (!addressCompleter.isCompleted) {
                addressCompleter.complete();
              }
            }
          } catch (e, st) {
            // Keep polling despite transient errors, but call onError
            NftCollection.logger.warning(
              '[$logPrefix][$address] poll error: $e',
            );
            unawaited(Sentry.captureException(e, stackTrace: st));
            final shouldComplete = await onError(e, st, address);
            if (shouldComplete) {
              completedAddresses.add(address);
              timer.cancel();
              addressTimers.remove(addressKey);
              if (!addressCompleter.isCompleted) {
                addressCompleter.complete();
              }
            }
          }
        },
      );
    }

    // Wait for all addresses to complete
    await Future.wait(
      addressCompleters.values.map((c) => c.future),
      eagerError: false,
    );

    // Cleanup all timers
    for (final timer in addressTimers.values) {
      timer.cancel();
    }
    addressTimers.clear();
    addressCompleters.clear();
  }

  @override
  Future<void> reindexByCidsAndPullStatus({
    required List<String> tokenCids,
    required Duration timeout,
    required FutureOr<bool> Function(
            WorkflowExecutionStatus status, String workflowId, String runId)
        onStatus,
    required FutureOr<void> Function() onTimeout,
    required FutureOr<void> Function(Object error, StackTrace stackTrace)
        onError,
  }) async {
    if (tokenCids.isEmpty) return;

    // Create key from tokenCids for deduplication
    final cidsKey = tokenCids.join(',');

    // If same tokenCids are already running, return the same completer
    final existingCompleter = _reindexCidsAndPullCompleters[cidsKey];
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      NftCollection.logger.info(
          '[reindexByCidsAndPullStatus] Token CIDs $tokenCids already being processed, returning existing completer');
      return existingCompleter.future;
    }

    // Create new completer for this operation
    final completer = Completer<void>();
    _reindexCidsAndPullCompleters[cidsKey] = completer;

    try {
      NftCollection.logger
          .info('[reindexByCidsAndPullStatus] Start for tokenCids: $tokenCids');

      // Call reindexTokensByCids
      final result = await reindexTokensByCids(tokenCids);
      final workflowId = result.workflowId;
      final runId = result.runId;

      // Cancel previous timer if any
      _reindexCidsAndPullTimers[cidsKey]?.cancel();

      final startedAt = DateTime.now();
      _reindexCidsAndPullTimers[cidsKey] = TimerExtension.periodicAndRunNow(
        const Duration(seconds: 15),
        (timer) async {
          try {
            // Skip polling if paused (app is in background)
            if (_isPollingPaused) {
              return;
            }

            // Check timeout
            if (DateTime.now().difference(startedAt) > timeout) {
              timer.cancel();
              _reindexCidsAndPullTimers.remove(cidsKey);
              _reindexCidsAndPullCompleters.remove(cidsKey);
              await onTimeout();
              if (!completer.isCompleted) {
                completer.complete();
              }
              return;
            }

            // Get workflow status
            final status =
                await _indexerService.getWorkflowStatus(workflowId, runId);
            NftCollection.logger.info(
                '[reindexByCidsAndPullStatus][$cidsKey] status: ${status.status.toJson()}');

            // Call onStatus callback - if returns true, complete and cleanup
            final shouldComplete =
                await onStatus(status.status, workflowId, runId);
            if (shouldComplete) {
              timer.cancel();
              _reindexCidsAndPullTimers.remove(cidsKey);
              _reindexCidsAndPullCompleters.remove(cidsKey);
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          } catch (e, st) {
            // Keep polling despite transient errors, but call onError
            NftCollection.logger.warning(
                '[reindexByCidsAndPullStatus][$cidsKey] poll error: $e');
            unawaited(Sentry.captureException(e, stackTrace: st));
            await onError(e, st);
          }
        },
      );
    } catch (e, st) {
      NftCollection.logger.warning('[reindexByCidsAndPullStatus] Error: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
      _reindexCidsAndPullCompleters.remove(cidsKey);
      _reindexCidsAndPullTimers[cidsKey]?.cancel();
      _reindexCidsAndPullTimers.remove(cidsKey);
      await onError(e, st);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }

    return completer.future;
  }

  @override
  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    List<AddressAnchor> addressAnchors,
  ) async {
    NftCollection.logger.info(
        '[updateTokensInIsolate][start] ${addressAnchors.map((e) => e.toJson().toString()).join(',')}');

    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final controller = StreamController<List<AssetToken>>();
    _streamControllers[uuid] = controller;

    final Map<String, String?> payload = {};
    for (final addressAnchor in addressAnchors) {
      payload[addressAnchor.address] = jsonEncode(addressAnchor.toJson());
    }

    _sendPort?.send([
      UPDATE_TOKENS_IN_ISOLATE,
      uuid,
      payload,
    ]);

    NftCollection.logger.info('[updateTokensInIsolate][start] '
        '${payload.keys.toList()}');
    return controller.stream;
  }

  Future<void> insertAssetsWithProvenance(List<AssetToken> assetTokens) async {
    _database.insertTokens(assetTokens);

    final tokensLog = assetTokens.map((e) => 'cid: ${e.cid}').toList();
    NftCollection.logger.info(
        '[insertAssetsWithProvenance][tokens] ${assetTokens.length} $tokensLog');
  }

  // fetch manual tokens from indexer in batches of 40
  Future<List<AssetToken>> _fetchManualTokensInBatches(
      List<String> cids) async {
    final batches = cids.batch(40);
    final manuallyAssets = <AssetToken>[];
    for (final batch in batches) {
      final assetTokenFromIndexer = await _fetchManualTokensInIsolate(batch);
      manuallyAssets.addAll(assetTokenFromIndexer);
    }
    return manuallyAssets;
  }

  // Fetch manual tokens via isolate (network call happens in isolate)
  Future<List<AssetToken>> _fetchManualTokensInIsolate(
      List<String> cids) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final completer = Completer<List<AssetToken>>();
    _fetchManualTokensCompleters[uuid] = completer;

    _sendPort?.send([FETCH_MANUAL_TOKENS, uuid, cids]);

    NftCollection.logger
        .info('[FETCH_MANUAL_TOKENS][start] UUID: $uuid, cids: $cids');
    return completer.future;
  }

  @override
  Future<List<AssetToken>> getManualTokens({
    required List<String> cids,
    bool shouldCallIndexer = true,
  }) async {
    try {
      // get from database
      final assetTokenFromDatabase = _database.getTokensByCIDs(cids: cids);
      final res = [...assetTokenFromDatabase];
      final missingIds = cids
          .where((cid) => !assetTokenFromDatabase.any((e) => e.cid == cid))
          .toList();
      if (missingIds.isNotEmpty) {
        if (shouldCallIndexer) {
          final assetTokenFromIndexer =
              await _fetchManualTokensInBatches(missingIds);
          res.addAll(assetTokenFromIndexer);
        }
      }
      // reorder the res to match the indexerIds
      res.sort(
        (a, b) => cids.indexOf(a.cid).compareTo(
              cids.indexOf(b.cid),
            ),
      );
      return res;
    } catch (e, st) {
      NftCollection.logger.warning('[TokensService] getManualTokens error: $e');
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('getManualTokens error: $e'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': st.toString(),
        },
        throwable: e,
      )));

      return [];
    }
  }

  @override
  Future<List<AssetToken>> fetchManualTokens({
    required List<String> cids,
  }) async {
    return _fetchManualTokensInBatches(cids);
  }

  /// Get owners and provenance events for a token by CID
  /// This method only returns owners and provenance events, not the full token
  ///
  /// [cid] - Token CID
  /// [ownersLimit] - Maximum number of owners to return (default: 255)
  /// [ownersOffset] - Offset for owners pagination (default: 0)
  /// [provenanceEventsLimit] - Maximum number of provenance events to return (default: 255)
  /// [provenanceEventsOffset] - Offset for provenance events pagination (default: 0)
  ///
  /// Returns TokenOwnersAndProvenance with owners and provenance_events including total and offset
  Future<TokenOwnersAndProvenance?> getOwnerAndProvenanceOfToken({
    required String cid,
    int ownersLimit = 255,
    int ownersOffset = 0,
    int provenanceEventsLimit = 255,
    int provenanceEventsOffset = 0,
  }) async {
    try {
      final result = await _indexerService.getOwnerAndProvenanceOfToken(
        cid: cid,
        ownersLimit: ownersLimit,
        ownersOffset: ownersOffset,
        provenanceEventsLimit: provenanceEventsLimit,
        provenanceEventsOffset: provenanceEventsOffset,
      );

      return result;
    } catch (e, st) {
      NftCollection.logger.warning(
        '[TokensService] getOwnerAndProvenanceOfToken error: $e',
      );
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('getOwnerAndProvenanceOfToken error: $e'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': st.toString(),
          'cid': cid,
        },
        throwable: e,
      )));

      return null;
    }
  }

  /// Get ALL owners and provenance events for a token by CID
  /// This method loops until all owners and provenance events are fetched
  /// Fetches both owners and provenance events together in each request
  ///
  /// [cid] - Token CID
  /// [startOwnerOffset] - Starting offset for owners pagination (default: 0)
  /// [startProvenanceOffset] - Starting offset for provenance events pagination (default: 0)
  ///
  /// Returns TokenOwnersAndProvenance with all owners and provenance_events combined
  static Future<TokenOwnersAndProvenance?> getAllOwnerAndProvenanceOfToken({
    required String cid,
    int startOwnerOffset = 0,
    int startProvenanceOffset = 0,
    required NftIndexerService indexerService,
  }) async {
    try {
      final allOwners = <Owner>[];
      final allProvenanceEvents = <ProvenanceEvent>[];

      int? currentOwnerOffset = startOwnerOffset;
      int? currentProvenanceOffset = startProvenanceOffset;
      int totalOwners = 0;
      int totalProvenanceEvents = 0;
      bool ownersComplete = false;
      bool provenanceComplete = false;
      int maxLoops = 10;
      int loopCount = 0;

      // Fetch owners and provenance events together until both are complete
      while ((!ownersComplete || !provenanceComplete) && loopCount < maxLoops) {
        loopCount++;
        NftCollection.logger.info(
          '[TokensService] getAllOwnerAndProvenanceOfToken $cid loop $loopCount, currentOwnerOffset: $currentOwnerOffset, currentProvenanceOffset: $currentProvenanceOffset',
        );
        final result = await indexerService.getOwnerAndProvenanceOfToken(
          cid: cid,
          ownersLimit: ownersComplete ? 0 : 255,
          ownersOffset: currentOwnerOffset ?? 0,
          provenanceEventsLimit: provenanceComplete ? 0 : 255,
          provenanceEventsOffset: currentProvenanceOffset ?? 0,
        );

        if (result == null) {
          break;
        }

        NftCollection.logger.info(
          '[TokensService] getAllOwnerAndProvenanceOfToken $cid loop $loopCount, result: owners: ${result.owners?.items.length}, provenanceEvents: ${result.provenanceEvents?.items.length}',
          'ownersComplete: $ownersComplete, provenanceComplete: $provenanceComplete',
        );

        totalOwners = result.owners?.total ?? 0;
        totalProvenanceEvents = result.provenanceEvents?.total ?? 0;

        // Process owners
        if (!ownersComplete && result.owners != null) {
          final owners = result.owners!;
          allOwners.addAll(owners.items);
          totalOwners = owners.total;

          // Check if owners are complete
          final nextOffset = owners.offset;
          if (nextOffset == null ||
              owners.items.isEmpty ||
              allOwners.length >= totalOwners) {
            ownersComplete = true;
            currentOwnerOffset = nextOffset;
          } else {
            currentOwnerOffset = nextOffset;
          }
        } else if (!ownersComplete) {
          ownersComplete = true;
        }

        // Process provenance events
        if (!provenanceComplete && result.provenanceEvents != null) {
          final provenanceEvents = result.provenanceEvents!;
          allProvenanceEvents.addAll(provenanceEvents.items);

          // Check if provenance events are complete
          // Use same logic as owners: check offset, items empty, or total reached
          final nextOffset = provenanceEvents.offset;
          if (nextOffset == null ||
              provenanceEvents.items.isEmpty ||
              allProvenanceEvents.length >= provenanceEvents.total) {
            provenanceComplete = true;
            currentProvenanceOffset = nextOffset;
          } else {
            currentProvenanceOffset = nextOffset;
          }
        } else if (!provenanceComplete) {
          provenanceComplete = true;
        }
      }

      final result = TokenOwnersAndProvenance(
          owners: PaginatedOwners(
            items: allOwners,
            total: totalOwners,
            offset: currentOwnerOffset,
          ),
          provenanceEvents: PaginatedProvenanceEvents(
            items: allProvenanceEvents,
            total: totalProvenanceEvents,
            offset: currentProvenanceOffset,
          ));
      return result;
    } catch (e, st) {
      NftCollection.logger.warning(
        '[TokensService] getAllOwnerAndProvenanceOfToken error: $e',
      );
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('getAllOwnerAndProvenanceOfToken error: $e'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': st.toString(),
          'cid': cid,
        },
        throwable: e,
      )));

      return null;
    }
  }

  static void _isolateEntry(List<dynamic> arguments) {
    // Use runZonedGuarded to catch all unhandled exceptions in isolate
    runZonedGuarded(() {
      final sendPort = arguments[0] as SendPort;

      final receivePort = ReceivePort()..listen(_handleMessageInIsolate);
      _isolateSendPort = sendPort;

      _setupInjector(
        arguments[1] as String,
        arguments[2] as String,
      );
      _isolateSendPort?.send(receivePort.sendPort);
    }, (error, stackTrace) {
      // Catch any unhandled exceptions to prevent isolate from crashing
      NftCollection.logger.warning(
        '[TokensService][Isolate][_isolateEntry] Unhandled exception: $error\nStackTrace: $stackTrace',
      );
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Unhandled exception in isolate: $error'),
        level: SentryLevel.error,
        extra: {
          'stackTrace': stackTrace.toString(),
        },
        throwable: error,
      )));
      // Try to send error to main isolate if possible
      try {
        _isolateSendPort?.send(
          'UNHANDLED_ERROR: ${error.toString()}',
        );
      } catch (_) {
        // If sending fails, isolate will exit and main isolate will receive exit message
      }
    });
  }

  static void _setupInjector(String indexerUrl, String indexerAPIKey) {
    final indexerClient = IndexerClient(
      indexerUrl,
      indexerAPIKey: indexerAPIKey,
      httpTimeout: const Duration(seconds: 30),
    );

    _isolateScopeInjector
      ..registerLazySingleton(() => indexerClient)
      ..registerLazySingleton(
        () => NftIndexerService(indexerClient),
      );
  }

  Future<void> _handleMessageInMain(dynamic message) async {
    if (message is SendPort) {
      _sendPort = message;
      if (!_isolateReady.isCompleted) _isolateReady.complete();
      return;
    }

    final result = message;
    if (result is FetchTokensData) {
      if (result.assets.isNotEmpty) {
        await insertAssetsWithProvenance(result.assets);
      }
      NftCollection.logger
          .info('[${result.key}] receive ${result.assets.length} tokens');

      if (result.key == FETCH_ALL_TOKENS) {
        // Use UUID to find the correct stream controller
        final uuid = result.uuid;
        final worker = _fetchTokensWorkers[uuid];

        if (worker != null && !worker.isClosed) {
          // Send data to stream
          worker.sink.add(result.assets);
          NftCollection.logger.info(
            '[FETCH_ALL_TOKENS][FetchTokensData] Sent ${result.assets.length} tokens to stream for UUID: $uuid',
          );
        } else if (worker != null && worker.isClosed) {
          // Stream was already closed, remove from map
          _fetchTokensWorkers.remove(uuid);
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS][FetchTokensData] Stream was already closed for UUID: $uuid, cannot send ${result.assets.length} tokens',
          );
          Sentry.captureEvent(SentryEvent(
            message: SentryMessage(
                'Stream was already closed for UUID: $uuid, cannot send ${result.assets.length} tokens'),
            level: SentryLevel.error,
          ));
        } else if (worker == null) {
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS][FetchTokensData] No worker found for UUID: $uuid, cannot send ${result.assets.length} tokens',
          );
          Sentry.captureEvent(SentryEvent(
            message: SentryMessage(
                'No worker found for UUID: $uuid, cannot send ${result.assets.length} tokens'),
            level: SentryLevel.error,
          ));
        }
      }

      return;
    }

    if (result is FetchTokensSuccess) {
      NftCollection.logger
          .info('[${result.key}][FetchTokensSuccess] fetch tokens completed');

      if (result.key == FETCH_ALL_TOKENS) {
        // Use UUID to find the correct stream controller
        final uuid = result.uuid;
        final worker = _fetchTokensWorkers[uuid];

        if (worker != null && !worker.isClosed) {
          // Close stream when fetch is done
          await worker.close();
          _fetchTokensWorkers.remove(uuid);
          NftCollection.logger.fine(
            '[FETCH_ALL_TOKENS][FetchTokensSuccess]'
            ' ${result.addresses.join(',')} at ${DateTime.now()}',
          );
          NftCollection.logger.info(
              '[FETCH_ALL_TOKENS][FetchTokensSuccess][end] Stream closed for UUID: $uuid, addresses: ${result.addresses.join(',')}');
        } else if (worker != null && worker.isClosed) {
          // Stream was already closed, remove from map
          _fetchTokensWorkers.remove(uuid);
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS][FetchTokensSuccess] Stream was already closed for UUID: $uuid',
          );
        } else if (worker == null) {
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS] No worker found for UUID: $uuid',
          );
        }
      }

      return;
    }

    if (result is FetchTokenFailure) {
      NftCollection.logger.info(
          '[FETCH_ALL_TOKENS][FetchTokenFailure] end in error ${result.exception} for addresses: ${result.addresses}');
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('FetchTokenFailure: ${result.exception}'),
        level: SentryLevel.error,
        extra: {
          'addresses': result.addresses,
        },
      )));

      if (result.key == FETCH_ALL_TOKENS) {
        // Use UUID to find the correct stream controller
        final uuid = result.uuid;
        final worker = _fetchTokensWorkers[uuid];

        if (worker != null && !worker.isClosed) {
          // Add error to stream and close it
          worker.sink.addError(result.exception);
          await worker.close();
          _fetchTokensWorkers.remove(uuid);
          NftCollection.logger.info(
              '[FETCH_ALL_TOKENS][FetchTokenFailure][end] Stream closed with error for UUID: $uuid, addresses: ${result.addresses.join(',')}');
        } else if (worker != null && worker.isClosed) {
          // Stream was already closed, remove from map
          _fetchTokensWorkers.remove(uuid);
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS][FetchTokenFailure] Stream was already closed for UUID: $uuid',
          );
          Sentry.captureEvent(SentryEvent(
            message: SentryMessage(
                '[FETCH_ALL_TOKENS][FetchTokenFailure] Stream was already closed for UUID: $uuid'),
            level: SentryLevel.error,
          ));
        } else if (worker == null) {
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS][FetchTokenFailure] No worker found for UUID: $uuid',
          );
          Sentry.captureEvent(SentryEvent(
            message: SentryMessage(
                '[FETCH_ALL_TOKENS][FetchTokenFailure] No worker found for UUID: $uuid'),
            level: SentryLevel.error,
          ));
        }
      }

      return;
    }

    if (result is ReindexAddressesListDone) {
      final completer = _reindexAddressesCompleters[result.uuid];
      if (completer != null) {
        completer.complete(result.results);
        _reindexAddressesCompleters.remove(result.uuid);
        NftCollection.logger.info(
          '[reindexAddressesList][end] ${result.results.length} results',
        );
      }
      return;
    }

    if (result is ReindexAddressesFailure) {
      _reindexAddressesCompleters[result.uuid]?.completeError(result.exception);
      _reindexAddressesCompleters.remove(result.uuid);
      NftCollection.logger.info(
        '[reindexAddresses][error] ${result.uuid}: ${result.exception}',
      );
      return;
    }

    if (result is ReindexTokensDone) {
      _indexTokensCompleters[result.uuid]?.complete(result.result);
      _indexTokensCompleters.remove(result.uuid);
      NftCollection.logger.info(
        '[reindexTokensByCids][end] workflowId: ${result.result.workflowId}, runId: ${result.result.runId}',
      );
      return;
    }

    if (result is ReindexTokensFailure) {
      _indexTokensCompleters[result.uuid]?.completeError(result.exception);
      _indexTokensCompleters.remove(result.uuid);
      NftCollection.logger.info(
        '[reindexTokensByCids][error] ${result.uuid}: ${result.exception}',
      );
      return;
    }

    if (result is UpdateTokensData) {
      log.info(
        '[UpdateTokensData] ${result.uuid} - ${result.changesList.items.length} changes, next anchor: ${result.changesList.nextAnchor}',
      );
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        bool hasError = false;
        // Group changes by tokenCid

        final groupedChanges = result.changesList.items
            .groupBy((change) => change.tokenId?.toString() ?? '');
        final tokenIds =
            groupedChanges.keys.toList().where((id) => id.isNotEmpty).toList();

        // Get tokens from database
        final tokens = _database.getTokensByTokenIds(tokenIds: tokenIds);
        final updatedTokens = <AssetToken>[];

        // Apply all changes to each token
        for (final tokenId in tokenIds) {
          final changes = groupedChanges[tokenId]!;

          final originalToken = tokens
              .firstWhereOrNull((token) => token.id.toString() == tokenId);

          // Find current token in database
          var currentToken = originalToken?.copyWith();

          // Sort changes by changedAt to apply in chronological order
          final sortedChanges = changes.toList()
            ..sort((a, b) => a.changedAt.compareTo(b.changedAt));

          // Apply each change to the token
          for (final change in sortedChanges) {
            try {
              if ((change.isMint() || change.isTransfer()) &&
                  change.tokenCid != null) {
                // if the change is a mint, we need to fetch token from indexer, then insert into database
                final cid = change.tokenCid;
                final tokens = await getManualTokens(cids: [cid!]);
                final token = tokens.firstWhereOrNull((e) => e.cid == cid);
                if (token != null) {
                  currentToken = token;
                }
              }
              if (currentToken != null) {
                currentToken = currentToken.applyChange(change);
              } else {
                // NftCollection.logger.info(
                //     "[UpdateTokensSuccess] token not found in database: $tokenCid, change: ${change.toJson()}");
              }
            } catch (e) {
              NftCollection.logger.info("[UpdateTokensSuccess] error: $e");
              unawaited(Sentry.captureEvent(SentryEvent(
                message: SentryMessage("Failed to update token: $e " +
                    "change: ${change.toJson()}"),
                level: SentryLevel.error,
                throwable: e,
              )));
              hasError = true;
            }
          }

          if (currentToken != null &&
              (originalToken == null ||
                  (currentToken.updatedAt?.isAfter(
                          originalToken.updatedAt ?? DateTime(1971)) ??
                      false))) {
            updatedTokens.add(currentToken);
          }
        }

        // Insert updated tokens into database
        if (updatedTokens.isNotEmpty) {
          await insertAssetsWithProvenance(updatedTokens);
        }

        // Emit updated tokens to stream
        if (!controller.isClosed && !controller.isPaused) {
          controller.add(updatedTokens);
        }

        NftCollection.logger.info(
          '[UPDATE_TOKENS_IN_ISOLATE][end] ${result.uuid} - Updated ${updatedTokens.length} tokens',
        );
        if (!hasError && result.changesList.nextAnchor != null) {
          NftCollection.logger.info(
              '[UPDATE_TOKENS_IN_ISOLATE][update ] ${result.changesList.nextAnchor}');
          final addresses = result.addresses;
          final addressAnchors = addresses
              .map((address) => AddressAnchor(
                  address: address, anchor: result.changesList.nextAnchor!))
              .toList();
          injector<UserDp1PlaylistService>()
              .updateLastUpdateChangeAnchor(addressAnchors: addressAnchors);
        }
      }
      return;
    }

    if (result is UpdateTokensSuccess) {
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        controller.add([]);
        await controller.close();
        _streamControllers.remove(result.uuid);
      }
      NftCollection.logger.info(
        '[UPDATE_TOKENS_IN_ISOLATE][end] ${result.uuid} - Stream closed',
      );
      return;
    }

    if (result is UpdateTokensFailure) {
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        controller.addError(result.exception);
        await controller.close();
        _streamControllers.remove(result.uuid);
      }
      Sentry.captureException(result.exception);
      NftCollection.logger.info(
        '[UPDATE_TOKENS_IN_ISOLATE][error] ${result.uuid} - ${result.exception}',
      );
      return;
    }

    if (result is FetchManualTokensDone) {
      final completer = _fetchManualTokensCompleters[result.uuid];
      if (completer != null && !completer.isCompleted) {
        completer.complete(result.tokens);
        _fetchManualTokensCompleters.remove(result.uuid);
        NftCollection.logger.info(
          '[FETCH_MANUAL_TOKENS][done] UUID: ${result.uuid}, tokens: ${result.tokens.length}',
        );
        // Insert tokens into database
        if (result.tokens.isNotEmpty) {
          await insertAssetsWithProvenance(result.tokens);
        }
      }
      return;
    }

    if (result is FetchManualTokensFailure) {
      final completer = _fetchManualTokensCompleters[result.uuid];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(result.exception);
        _fetchManualTokensCompleters.remove(result.uuid);
        NftCollection.logger.warning(
          '[FETCH_MANUAL_TOKENS][error] UUID: ${result.uuid}, error: ${result.exception}',
        );
      }
      return;
    }

    NftCollection.logger
        .info('[TokensService][_handleMessageInMain] Unknown message: $result');
    unawaited(Sentry.captureEvent(SentryEvent(
      message: SentryMessage('Unknown message: $result'),
      level: SentryLevel.error,
    )));
    return;
  }

  static SendPort? _isolateSendPort;

  static void _handleMessageInIsolate(dynamic message) {
    try {
      NftCollection.logger
          .info('[TokensService][Isolate] received message: $message');
      if (message is List<dynamic>) {
        switch (message[0]) {
          case FETCH_ALL_TOKENS:
            final uuid = message[1] as String;
            final addresses = List<String>.from(message[2] as List);
            final offset = message[3] as int?;
            final size = message[4] as int?;
            _fetchAllTokens(
              FETCH_ALL_TOKENS,
              uuid,
              addresses,
              offset,
              size,
            );
            break;

          case REINDEX_ADDRESSES_LIST:
            _reindexAddressesListInIndexer(
              message[1] as String,
              List<String>.from(message[2] as List),
            );
            break;

          case REINDEX_TOKENS:
            _reindexTokensInIndexer(
              message[1] as String,
              List<String>.from(message[2] as List),
            );
            break;

          case UPDATE_TOKENS_IN_ISOLATE:
            final addressAnchorsMessage = Map<String, String>.from(
              (message[2] as Map).map(
                (k, v) => MapEntry(k as String, v as String?),
              ),
            );
            final List<AddressAnchor> addressAnchors = [];
            for (final address in addressAnchorsMessage.values) {
              addressAnchors.add(AddressAnchor.fromJson(
                  Map<String, dynamic>.from(jsonDecode(address) as Map)));
            }
            _updateTokensInIsolate(
              message[1] as String,
              addressAnchors,
            );
            break;

          case FETCH_MANUAL_TOKENS:
            _fetchManualTokensInIsolateStatic(
              message[1] as String,
              List<String>.from(message[2] as List),
            );
            break;

          default:
            break;
        }
      }
    } catch (e, stackTrace) {
      // Catch any unhandled exceptions to prevent isolate from crashing
      NftCollection.logger.warning(
        '[TokensService][Isolate][_handleMessageInIsolate] Unhandled exception: $e\nStackTrace: $stackTrace',
      );
      // Try to send error to main isolate if possible
      try {
        _isolateSendPort?.send(
          'UNHANDLED_ERROR: ${e.toString()}',
        );
      } catch (_) {
        // If sending fails, isolate will exit and main isolate will receive exit message
      }
    }
  }

  static Future<void> _fetchAllTokens(
    String key,
    String uuid,
    List<String> addresses,
    int? offset,
    int? total,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      var numberOfToken = 0;
      var currentOffset = offset ?? 0;

      while (total == null || numberOfToken < total) {
        final tokens = await getTokensPageWithAllOwnersAndProvenances(
            isolateIndexerService, addresses, currentOffset);

        if (tokens.isEmpty) {
          break;
        }
        final sentTokens = total == null
            ? tokens
            : tokens.safeSublist(
                0, (total - numberOfToken).clamp(0, tokens.length));
        _isolateSendPort?.send(
          FetchTokensData(
            key,
            uuid,
            addresses,
            sentTokens,
          ),
        );

        currentOffset += sentTokens.length;
        numberOfToken += sentTokens.length;
      }

      _isolateSendPort?.send(FetchTokensSuccess(key, uuid, addresses));
    } catch (exception) {
      _isolateSendPort
          ?.send(FetchTokenFailure(key, uuid, addresses, exception));
    }
  }

  // Fetch a single tokens page (by offset) and progressively increase ownersLimit
  // until owners lists are fully retrieved (heuristic) or a safety cap is reached.
  static Future<List<AssetToken>> getTokensPageWithAllOwnersAndProvenances(
    NftIndexerService indexerService,
    List<String> addresses,
    int offset,
  ) async {
    final request = QueryListTokensRequest(
      owners: addresses,
      offset: offset,
      ownersOffset: 0,
    );
    final tokens = await indexerService.getNftTokens(request);
    Map<String, AssetToken> tokenMap =
        Map.fromEntries(tokens.map((token) => MapEntry(token.cid, token)));

    List<AssetToken> tokensToLoad = tokens
        .where((token) =>
            (token.owners != null &&
                token.owners!.items.length < token.owners!.total) ||
            (token.provenanceEvents != null &&
                token.provenanceEvents!.items.length <
                    token.provenanceEvents!.total))
        .toList();

    final token1155 = tokensToLoad
        .where((token) => token.standard.contains('erc1155'))
        .toList();

    // load all owners and provenance events for each token in batches
    for (final batch in tokensToLoad.toList().batch(10)) {
      final futures = batch.map((token) async {
        try {
          return await _loadOwnersAndProvenanceForToken(indexerService, token);
        } catch (e) {
          NftCollection.logger.warning(
            '[TokensService] _loadOwnersAndProvenanceForToken ${token.cid} error: $e',
          );
          unawaited(Sentry.captureException(e));
          return null;
        }
      });
      final results = await Future.wait(futures);
      for (final result in results) {
        if (result != null) {
          tokenMap[result.cid] = result;
        }
      }
    }

    return tokenMap.values.toList();
  }

  static Future<AssetToken> _loadOwnersAndProvenanceForToken(
    NftIndexerService indexerService,
    AssetToken token,
  ) async {
    final result = await getAllOwnerAndProvenanceOfToken(
      cid: token.cid,
      indexerService: indexerService,
      startOwnerOffset: token.owners?.items.length ?? 0,
      startProvenanceOffset: token.provenanceEvents?.items.length ?? 0,
    );
    final owners = result?.owners;
    final provenanceEvents = result?.provenanceEvents;
    final newOwners = PaginatedOwners(
      items: [...(token.owners?.items ?? []), ...(owners?.items ?? [])],
      total: owners?.total ?? 0,
      offset: owners?.offset,
    );
    final newProvenanceEventsItems = <ProvenanceEvent>[
      ...(token.provenanceEvents?.items ?? []),
      ...(provenanceEvents?.items ?? [])
    ].toSet().toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final newProvenanceEvents = PaginatedProvenanceEvents(
      items: newProvenanceEventsItems,
      total: provenanceEvents?.total ?? 0,
      offset: provenanceEvents?.offset,
    );
    return token.copyWith(
        owners: newOwners, provenanceEvents: newProvenanceEvents);
  }

  static Future<void> _reindexAddressesListInIndexer(
      String uuid, List<String> addresses) async {
    try {
      final indexerService = _isolateScopeInjector<NftIndexerService>();
      final results = await indexerService.indexAddressesList(addresses);

      // Send the list of results
      _isolateSendPort?.send(ReindexAddressesListDone(uuid, results));
    } catch (e) {
      _isolateSendPort?.send(ReindexAddressesFailure(uuid, e));
    }
  }

  static Future<void> _reindexTokensInIndexer(
      String uuid, List<String> tokenCids) async {
    try {
      final indexerService = _isolateScopeInjector<NftIndexerService>();
      final result = await indexerService.indexTokens(tokenCids);

      // Send the result (indexTokens always returns a result for non-empty tokenCids)
      _isolateSendPort?.send(ReindexTokensDone(uuid, result));
    } catch (e) {
      _isolateSendPort?.send(ReindexTokensFailure(uuid, e));
    }
  }

  static Future<void> _fetchManualTokensInIsolateStatic(
    String uuid,
    List<String> cids,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      final request = QueryListTokensRequest(
        tokenCids: cids,
        limit: cids.length,
      );

      final tokens = await isolateIndexerService.getNftTokens(request);

      final missingCids =
          cids.where((cid) => !tokens.any((e) => e.cid == cid)).toList();

      if (missingCids.isNotEmpty) {
        // Try to reindex missing tokens
        try {
          final res = await isolateIndexerService.indexTokens(missingCids);
          // Wait for indexing to complete
          while (true) {
            final status = await isolateIndexerService.getWorkflowStatus(
              res.workflowId,
              res.runId,
            );
            if (status.status.isDone) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
          // Fetch again after reindexing
          final retryRequest = QueryListTokensRequest(
            tokenCids: missingCids,
            limit: missingCids.length,
          );
          final retryTokens =
              await isolateIndexerService.getNftTokens(retryRequest);
          tokens.addAll(retryTokens);
        } catch (e) {
          NftCollection.logger.warning(
            '[FETCH_MANUAL_TOKENS][reindex] Error reindexing missing tokens: $e',
          );
        }
      }

      NftCollection.logger.info(
        '[FETCH_MANUAL_TOKENS][done] UUID: $uuid, fetched ${tokens.length} tokens for cids: $cids',
      );

      _isolateSendPort?.send(FetchManualTokensDone(uuid, tokens));
    } catch (exception) {
      NftCollection.logger.warning(
        '[FETCH_MANUAL_TOKENS][error] UUID: $uuid, error: $exception',
      );
      _isolateSendPort?.send(FetchManualTokensFailure(uuid, exception));
    }
  }

  static Future<void> _updateTokensInIsolate(
    String uuid,
    List<AddressAnchor> addressAnchors,
  ) async {
    final addresses = addressAnchors.map((e) => e.address).toList();
    final anchors = addressAnchors.map((e) => e.anchor).toList();
    try {
      if (addresses.isEmpty) {
        throw Exception('Addresses list cannot be empty');
      }

      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();

      // Get all addresses and find the oldest sinceIso time

      final anchor = anchors.isEmpty
          ? null
          : anchors.reduce((a, b) => a.compareTo(b) < 0 ? a : b);

      // Fetch changes for all addresses at once
      final changesStream = _getChangesForAddress(
        isolateIndexerService,
        addresses,
        anchor,
      );

      // Listen to the changes stream and send UpdateTokensData for each batch
      await changesStream.forEach((changesList) {
        _isolateSendPort?.send(UpdateTokensData(uuid, changesList, addresses));
      });

      // Send all changes to main isolate to fetch tokens from database
      _isolateSendPort?.send(
        UpdateTokensSuccess(uuid),
      );
    } catch (exception) {
      _isolateSendPort?.send(UpdateTokensFailure(
        uuid,
        exception,
        addresses,
      ));
    }
  }

  static Stream<ChangeList> _getChangesForAddress(
    NftIndexerService service,
    List<String> addresses,
    int? anchor,
  ) async* {
    const pageSize = 50;
    int? nextAnchor = anchor;

    while (true) {
      final req = QueryChangesRequest(
        addresses: addresses,
        limit: pageSize,
        anchor: nextAnchor,
      );
      final page = await service.getChanges(req);
      if (page.items.isEmpty) break;

      // Yield each page of changes to the stream
      yield page;

      nextAnchor = page.nextAnchor;
      if (nextAnchor == null) break;
    }
  }
}

class AddressAnchor {
  AddressAnchor({required this.address, required this.anchor});
  factory AddressAnchor.fromJson(Map<String, dynamic> json) => AddressAnchor(
        address: json['address'] as String,
        anchor: json['anchor'] as int,
      );

  final String address;
  final int anchor;

  Map<String, dynamic> toJson() => {
        'address': address,
        'anchor': anchor,
      };
}

abstract class TokensServiceResult {}

class FetchTokensData extends TokensServiceResult {
  FetchTokensData(
    this.key,
    this.uuid,
    this.addresses,
    this.assets,
  );

  final String key;
  final String uuid;
  final List<String> addresses;
  final List<AssetToken> assets;
}

class FetchTokensSuccess extends TokensServiceResult {
  FetchTokensSuccess(
    this.key,
    this.uuid,
    this.addresses,
  );

  final String key;
  final String uuid;
  final List<String> addresses;
}

class FetchTokenFailure extends TokensServiceResult {
  FetchTokenFailure(this.key, this.uuid, this.addresses, this.exception);

  final String uuid;
  final String key;
  final List<String> addresses;
  final Object exception;
}

class ReindexAddressesFailure extends TokensServiceResult {
  ReindexAddressesFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
}

class ReindexAddressesListDone extends TokensServiceResult {
  ReindexAddressesListDone(this.uuid, this.results);

  final String uuid;
  final List<AddressIndexingResult> results;
}

class ReindexTokensDone extends TokensServiceResult {
  ReindexTokensDone(this.uuid, this.result);

  final String uuid;
  final TriggerIndexingResult result;
}

class ReindexTokensFailure extends TokensServiceResult {
  ReindexTokensFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
}

class UpdateTokensSuccess extends TokensServiceResult {
  UpdateTokensSuccess(this.uuid);

  final String uuid;
}

class UpdateTokensData extends TokensServiceResult {
  UpdateTokensData(this.uuid, this.changesList, this.addresses);

  final String uuid;
  final ChangeList changesList;
  final List<String> addresses;
}

class UpdateTokensFailure extends TokensServiceResult {
  UpdateTokensFailure(this.uuid, this.exception, this.addresses);

  final String uuid;
  final Object exception;
  final List<String> addresses;
}

class FetchManualTokensDone extends TokensServiceResult {
  FetchManualTokensDone(this.uuid, this.tokens);

  final String uuid;
  final List<AssetToken> tokens;
}

class FetchManualTokensFailure extends TokensServiceResult {
  FetchManualTokensFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
}
