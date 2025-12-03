//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

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
import 'package:collection/collection.dart';
import 'package:get_it/get_it.dart';
import 'package:sentry/sentry.dart';
import 'package:uuid/uuid.dart';

abstract class NftTokensService {
  Future<List<AssetToken>> getManualTokens({
    required List<String> cids,
    bool shouldCallIndexer = true,
  });

  Future<Stream<List<AssetToken>>> fetchTokensInIsolate(
    List<String> addresses,
    int? offset,
    int? total,
  );

  Future<TriggerIndexingResult?> reindexAddresses(List<String> addresses);

  Future<TriggerIndexingResult> reindexTokensByCids(
    List<String> tokenCids,
  );

  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    List<AddressAnchor> addressAnchors,
  );

  Future<void> reindexAddressesAndPullStatus({
    required List<String> addresses,
    required Duration timeout,
    required FutureOr<bool> Function(WorkflowExecutionStatus status,
            String workflowId, String runId, List<String> batchAddresses)
        onStatus,
    required FutureOr<void> Function(List<String> batchAddresses) onTimeout,
    required FutureOr<void> Function(
            Object error, StackTrace stackTrace, List<String> batchAddresses)
        onError,
    FutureOr<void> Function(List<String> addresses)? onBatchStart,
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
    );
    _indexerService = NftIndexerService(indexerClient);
  }

  final String _indexerUrl;
  final String _indexerAPIKey;
  late NftIndexerService _indexerService;
  final IndexerDatabaseAbstract _database;
  final NftCollectionPrefs _configurationService;

  static const FETCH_ALL_TOKENS = 'FETCH_ALL_TOKENS';
  static const REINDEX_ADDRESSES = 'REINDEX_ADDRESSES';
  static const REINDEX_TOKENS = 'REINDEX_TOKENS';
  static const UPDATE_TOKENS_IN_ISOLATE = 'UPDATE_TOKENS_IN_ISOLATE';

  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  var _isolateReady = Completer<void>();
  // Map of UUID to stream controller for deduplication
  final Map<String, StreamController<List<AssetToken>>> _fetchTokensWorkers =
      {};

  final Map<String, Completer<TriggerIndexingResult>>
      _reindexAddressesCompleters = {};
  final Map<String, Completer<TriggerIndexingResult>> _indexTokensCompleters =
      {};
  final Map<String, StreamController<List<AssetToken>>> _streamControllers = {};
  // Track running reindex operations by addresses key (deduplication)
  final Map<String, Completer<void>> _reindexAndPullCompleters = {};
  final Map<String, Timer> _reindexAndPullTimers = {};
  // Track running reindex operations by token CIDs key (deduplication)
  final Map<String, Completer<void>> _reindexCidsAndPullCompleters = {};
  final Map<String, Timer> _reindexCidsAndPullTimers = {};

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
    // Cancel all reindex and pull timers
    for (final timer in _reindexAndPullTimers.values) {
      timer.cancel();
    }
    _reindexAndPullTimers.clear();

    for (final completer in _reindexAndPullCompleters.values) {
      completer.completeError(Exception('Isolate disposed'));
    }
    _reindexAndPullCompleters.clear();
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
    await _configurationService.setDidSyncAddress(false);
    _database.clearAll();
    await injector<ConfigurationService>().clearAddressLastFetchTokenTime();
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
  Future<TriggerIndexingResult?> reindexAddresses(
      List<String> addresses) async {
    if (addresses.isEmpty) {
      throw ArgumentError('Addresses list cannot be empty');
    }

    await startIsolateOrWait();

    // Process addresses in batches of 5
    const batchSize = 5;
    TriggerIndexingResult? lastResult;

    for (var i = 0; i < addresses.length; i += batchSize) {
      try {
        final batch = addresses.skip(i).take(batchSize).toList();
        final uuid = const Uuid().v4();
        final completer = Completer<TriggerIndexingResult>();
        _reindexAddressesCompleters[uuid] = completer;

        if (_sendPort == null) {
          throw Exception('Isolate not started');
        }

        _sendPort?.send([REINDEX_ADDRESSES, uuid, batch]);

        NftCollection.logger.fine(
            '[reindexAddresses][batch ${i ~/ batchSize + 1}][start] $batch');
        lastResult = await completer.future;
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
        ;
      }
    }

    NftCollection.logger.fine(
        '[reindexAddresses][complete] processed ${addresses.length} addresses in ${(addresses.length / batchSize).ceil()} batches');
    return lastResult;
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
  Future<void> reindexAddressesAndPullStatus({
    required List<String> addresses,
    required Duration timeout,
    required FutureOr<bool> Function(WorkflowExecutionStatus status,
            String workflowId, String runId, List<String> batchAddresses)
        onStatus,
    required FutureOr<void> Function(List<String> batchAddresses) onTimeout,
    required FutureOr<void> Function(
            Object error, StackTrace stackTrace, List<String> batchAddresses)
        onError,
    FutureOr<void> Function(List<String> addresses)? onBatchStart,
  }) async {
    if (addresses.isEmpty) return;

    // Create key from addresses for deduplication
    final addressesKey = addresses.join(',');

    // If same addresses are already running, return the same completer
    final existingCompleter = _reindexAndPullCompleters[addressesKey];
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      NftCollection.logger.info(
          '[reindexAddressesAndPullStatus] Addresses $addresses already being processed, returning existing completer');
      return existingCompleter.future;
    }

    // Create new completer for this operation
    final completer = Completer<void>();
    _reindexAndPullCompleters[addressesKey] = completer;

    // Process addresses in batches of 5
    const batchSize = 5;

    try {
      NftCollection.logger.info(
          '[reindexAddressesAndPullStatus] Start for addresses: $addresses');
      final batches = <List<String>>[];
      for (var i = 0; i < addresses.length; i += batchSize) {
        batches.add(addresses.skip(i).take(batchSize).toList());
      }

      NftCollection.logger.info(
          '[reindexAddressesAndPullStatus] Processing ${addresses.length} addresses in ${batches.length} batches');

      // Process each batch sequentially
      for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
        final batch = batches[batchIndex];
        final batchKey = batch.join(',');

        NftCollection.logger.info(
            '[reindexAddressesAndPullStatus][batch ${batchIndex + 1}/${batches.length}] Processing batch: $batch');

        // Call onBatchStart callback if provided
        if (onBatchStart != null) {
          await onBatchStart(batch);
        }

        // Call reindexAddresses for this batch
        final result = await reindexAddresses(batch);
        if (result == null) {
          NftCollection.logger.warning(
              '[reindexAddressesAndPullStatus][batch ${batchIndex + 1}][$batchKey] reindexAddresses failed');
          await onError(
              Exception('Reindex addresses failed'), StackTrace.current, batch);
          continue;
        }
        final workflowId = result.workflowId;
        final runId = result.runId;

        // Cancel previous timer if any
        _reindexAndPullTimers[batchKey]?.cancel();

        final startedAt = DateTime.now();
        final batchCompleter = Completer<void>();
        _reindexAndPullTimers[batchKey] = Timer.periodic(
          const Duration(seconds: 15),
          (timer) async {
            try {
              // Check timeout
              if (DateTime.now().difference(startedAt) > timeout) {
                timer.cancel();
                _reindexAndPullTimers.remove(batchKey);
                await onTimeout(batch);
                if (!batchCompleter.isCompleted) {
                  batchCompleter.complete();
                }
                return;
              }

              // Get workflow status
              final status =
                  await _indexerService.getWorkflowStatus(workflowId, runId);
              NftCollection.logger.info(
                  '[reindexAddressesAndPullStatus][batch ${batchIndex + 1}][$batchKey] status: ${status.status.toJson()}');

              // Call onStatus callback - if returns true, complete and cleanup
              final shouldComplete =
                  await onStatus(status.status, workflowId, runId, batch);
              if (shouldComplete) {
                timer.cancel();
                _reindexAndPullTimers.remove(batchKey);
                if (!batchCompleter.isCompleted) {
                  batchCompleter.complete();
                }
              }
            } catch (e, st) {
              // Keep polling despite transient errors, but call onError
              NftCollection.logger.warning(
                  '[reindexAddressesAndPullStatus][batch ${batchIndex + 1}][$batchKey] poll error: $e');
              unawaited(Sentry.captureException(e, stackTrace: st));
              await onError(e, st, batch);
            }
          },
        );

        // Wait for this batch to complete before processing next batch
        await batchCompleter.future;
        _reindexAndPullTimers[batchKey]?.cancel();
        _reindexAndPullTimers.remove(batchKey);

        NftCollection.logger.info(
            '[reindexAddressesAndPullStatus][batch ${batchIndex + 1}/${batches.length}] Completed');
      }

      // All batches completed
      _reindexAndPullCompleters.remove(addressesKey);
      if (!completer.isCompleted) {
        completer.complete();
      }

      NftCollection.logger.info(
          '[reindexAddressesAndPullStatus] All batches completed for addresses: $addresses');
    } catch (e, st) {
      NftCollection.logger.warning('[reindexAddressesAndPullStatus] Error: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
      _reindexAndPullCompleters.remove(addressesKey);
      // Cancel all batch timers
      for (var i = 0; i < addresses.length; i += batchSize) {
        final batch = addresses.skip(i).take(batchSize).toList();
        final batchKey = batch.join(',');
        _reindexAndPullTimers[batchKey]?.cancel();
        _reindexAndPullTimers.remove(batchKey);
      }
      await onError(e, st, addresses);
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }

    return completer.future;
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
      _reindexCidsAndPullTimers[cidsKey] = Timer.periodic(
        const Duration(seconds: 15),
        (timer) async {
          try {
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
    for (final assetToken in assetTokens) {
      _database.insertToken(assetToken);
    }

    final tokensLog = assetTokens.map((e) => 'cid: ${e.cid}').toList();
    NftCollection.logger.info(
        '[insertAssetsWithProvenance][tokens] ${assetTokens.length} $tokensLog');
  }

  // fetch manual tokens from indexer in batches of 20
  Future<List<AssetToken>> _fetchManualTokensInBatches(
      List<String> cids) async {
    final batches = cids.batch(40);
    final manuallyAssets = <AssetToken>[];
    for (final batch in batches) {
      final assetTokenFromIndexer = await _fetchManualTokens(batch);
      manuallyAssets.addAll(assetTokenFromIndexer);
    }
    return manuallyAssets;
  }

  Future<List<AssetToken>> _fetchManualTokens(List<String> cids,
      {bool shouldCallIndexer = true}) async {
    final request = QueryListTokensRequest(
      tokenCids: cids,
      limit: cids.length,
    );

    final manuallyAssets = await _indexerService.getNftTokens(request);

    final missingCids =
        cids.where((cid) => !manuallyAssets.any((e) => e.cid == cid)).toList();

    if (missingCids.isNotEmpty && shouldCallIndexer) {
      // reindex the missing cids
      final res = await reindexTokensByCids(missingCids);

      // pull the status
      while (true) {
        final status =
            await _indexerService.getWorkflowStatus(res.workflowId, res.runId);
        if (status.status.isDone) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final assetTokenFromIndexer =
          await _fetchManualTokens(missingCids, shouldCallIndexer: false);
      manuallyAssets.addAll(assetTokenFromIndexer);
    }

    NftCollection.logger.info('[TokensService] '
        'fetched ${manuallyAssets.length} manual tokens. '
        'IDs: $cids');
    if (manuallyAssets.isNotEmpty) {
      await insertAssetsWithProvenance(manuallyAssets);
    }
    return manuallyAssets;
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
    if (result is FetchTokensSuccess) {
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
            '[FETCH_ALL_TOKENS] Sent ${result.assets.length} tokens to stream for UUID: $uuid, done: ${result.done}',
          );

          // Close stream after sending data when done
          if (result.done) {
            await worker.close();
            _fetchTokensWorkers.remove(uuid);
            NftCollection.logger.fine(
              '[FETCH_ALL_TOKENS]'
              ' ${result.addresses.join(',')} at ${DateTime.now()}',
            );
            NftCollection.logger.info(
                '[FETCH_ALL_TOKENS][end] Stream closed for UUID: $uuid, addresses: ${result.addresses.join(',')}');
          }
        } else if (worker != null && worker.isClosed) {
          // Stream was already closed, remove from map
          _fetchTokensWorkers.remove(uuid);
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS] Stream was already closed for UUID: $uuid, cannot send ${result.assets.length} tokens',
          );
        } else if (worker == null) {
          NftCollection.logger.warning(
            '[FETCH_ALL_TOKENS] No worker found for UUID: $uuid, cannot send ${result.assets.length} tokens',
          );
        }
      }

      return;
    }

    if (result is FetchTokenFailure) {
      NftCollection.logger.info(
          '[FETCH_ALL_TOKENS] end in error ${result.exception} for addresses: ${result.addresses}');
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('FetchTokenFailure: ${result.exception}'),
        level: SentryLevel.error,
        extra: {
          'addresses': result.addresses,
        },
      )));

      // Use UUID to find the correct stream controller
      final uuid = result.uuid;
      final worker = _fetchTokensWorkers[uuid];

      if (worker != null && !worker.isClosed) {
        await worker.close();
        _fetchTokensWorkers.remove(uuid);
      }
      _reindexAddressesCompleters[result.uuid]?.completeError(result.exception);
      _reindexAddressesCompleters.remove(result.uuid);
      return;
    }

    if (result is ReindexAddressesDone) {
      _reindexAddressesCompleters[result.uuid]?.complete(result.result);
      _reindexAddressesCompleters.remove(result.uuid);
      NftCollection.logger.info(
        '[reindexAddresses][end] workflowId: ${result.result.workflowId}, runId: ${result.result.runId}',
      );
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

          case REINDEX_ADDRESSES:
            _reindexAddressesInIndexer(
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
        final tokens = await getTokensPageWithAllOwners(
            isolateIndexerService, addresses, currentOffset);

        if (tokens.isEmpty) {
          break;
        }
        final sentTokens = total == null
            ? tokens
            : tokens.safeSublist(
                0, (total - numberOfToken).clamp(0, tokens.length));
        _isolateSendPort?.send(
          FetchTokensSuccess(
            key,
            uuid,
            addresses,
            sentTokens,
            false,
          ),
        );

        currentOffset += sentTokens.length;
        numberOfToken += sentTokens.length;
      }

      _isolateSendPort
          ?.send(FetchTokensSuccess(key, uuid, addresses, [], true));
    } catch (exception) {
      _isolateSendPort
          ?.send(FetchTokenFailure(key, uuid, addresses, exception));
    }
  }

  // Fetch a single tokens page (by offset) and progressively increase ownersLimit
  // until owners lists are fully retrieved (heuristic) or a safety cap is reached.
  static Future<List<AssetToken>> getTokensPageWithAllOwners(
    NftIndexerService indexerService,
    List<String> addresses,
    int offset,
  ) async {
    var ownersOffset = 0;
    final request = QueryListTokensRequest(
      owners: addresses,
      offset: offset,
      ownersOffset: ownersOffset,
    );
    final tokens = await indexerService.getNftTokens(request);
    Map<String, AssetToken> tokenMap =
        Map.fromEntries(tokens.map((token) => MapEntry(token.cid, token)));
    ownersOffset = request.ownersLimit;

    List<AssetToken> lastTokens = tokens.toList();

    // looop to fetch more owners
    while (true) {
      // list token with owners limit not reached
      final tokensToFetch = lastTokens
          .where((token) => (token.owners?.total ?? 0) > ownersOffset)
          .toList();
      if (tokensToFetch.isEmpty) break;
      final request = QueryListTokensRequest(
        offset: 0,
        ownersOffset: ownersOffset,
        tokenCids: tokensToFetch.map((token) => token.cid).toList(),
      );
      final tokens = await indexerService.getNftTokens(request);
      tokens.forEach((token) {
        // insert new owners into token map
        final oldToken = tokenMap[token.cid];
        final oldOwners = oldToken?.owners;
        final oldItems = oldOwners?.items ?? [];
        final newItems = token.owners?.items ?? [];
        final newOwners = oldOwners?.copyWith(
          items: [...oldItems, ...newItems],
        );
        tokenMap[token.cid] = oldToken?.copyWith(owners: newOwners) ?? token;
      });
      lastTokens = tokens;
      ownersOffset = ownersOffset + request.ownersLimit;
    }
    return tokenMap.values.toList();
  }

  static Future<void> _reindexAddressesInIndexer(
      String uuid, List<String> addresses) async {
    try {
      final indexerService = _isolateScopeInjector<NftIndexerService>();
      TriggerIndexingResult? lastResult;

      lastResult = await indexerService.indexAddresses(addresses);

      // Send the result (indexAddresses always returns a result for non-empty addresses)
      _isolateSendPort?.send(ReindexAddressesDone(uuid, lastResult));
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

class FetchTokensSuccess extends TokensServiceResult {
  FetchTokensSuccess(
    this.key,
    this.uuid,
    this.addresses,
    this.assets,
    this.done,
  );

  final String key;
  final String uuid;
  final List<String> addresses;
  final List<AssetToken> assets;
  bool done;
}

class FetchTokenFailure extends TokensServiceResult {
  FetchTokenFailure(this.key, this.uuid, this.addresses, this.exception);

  final String uuid;
  final String key;
  final List<String> addresses;
  final Object exception;
}

class ReindexAddressesDone extends TokensServiceResult {
  ReindexAddressesDone(this.uuid, this.result);

  final String uuid;
  final TriggerIndexingResult result;
}

class ReindexAddressesFailure extends TokensServiceResult {
  ReindexAddressesFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
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
