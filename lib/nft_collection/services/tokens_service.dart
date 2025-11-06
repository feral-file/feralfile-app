//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:isolate';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_changes.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/graphql/queries/queries.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/list_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

// Auth bridge op-codes between isolates (top-level so both main and worker use them)
const String AUTH_OP = 'AUTH_OP';
const String AUTH_GET_TOKEN = 'AUTH_GET_TOKEN';
const String AUTH_REFRESH = 'AUTH_REFRESH';

abstract class NftTokensService {
  Future<List<AssetToken>> fetchManualTokens(List<String> cids);

  Future<List<AssetToken>> getManualTokens({
    required List<String> cids,
    bool shouldCallIndexer = true,
  });

  Future<Stream<List<AssetToken>>> fetchTokensInIsolate(
    List<String> addresses,
  );

  Future<TriggerIndexingResult> reindexAddresses(List<String> addresses);

  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    Map<String, DateTime?> addressToSince,
  );

  bool get isRefreshAllTokensListen;

  Future<void> purgeCachedGallery();
}

final _isolateScopeInjector = GetIt.asNewInstance();

class NftTokensServiceImpl extends NftTokensService {
  NftTokensServiceImpl(
    this._indexerUrl,
    this._database,
    this._configurationService,
  ) {
    final indexerClient = IndexerClient(
      _indexerUrl,
      authService: injector<AuthService>(),
    );
    _indexerService = NftIndexerService(indexerClient);
  }

  final String _indexerUrl;
  late NftIndexerService _indexerService;
  final IndexerDatabaseAbstract _database;
  final NftCollectionPrefs _configurationService;

  static const FETCH_ALL_TOKENS = 'FETCH_ALL_TOKENS';
  static const REINDEX_ADDRESSES = 'REINDEX_ADDRESSES';
  static const UPDATE_TOKENS_IN_ISOLATE = 'UPDATE_TOKENS_IN_ISOLATE';

  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  var _isolateReady = Completer<void>();
  List<String>? _currentAddresses;
  StreamController<List<AssetToken>>? _refreshAllTokensWorker;

  @override
  bool get isRefreshAllTokensListen =>
      _refreshAllTokensWorker?.hasListener ?? false;
  final Map<String, Completer<TriggerIndexingResult>>
      _reindexAddressesCompleters = {};
  final Map<String, StreamController<List<AssetToken>>> _streamControllers = {};

  Future<void> get isolateReady => _isolateReady.future;

  Future<void> start() async {
    if (_sendPort != null) return;

    _receivePort = ReceivePort();
    _receivePort!.listen(_handleMessageInMain);

    _isolate = await Isolate.spawn(_isolateEntry, [
      _receivePort!.sendPort,
      _indexerUrl,
    ]);
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
    _refreshAllTokensWorker?.close();
    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _isolate?.kill();
    _isolateSendPort = null;
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _currentAddresses = null;
    _isolateReady = Completer<void>();
    NftCollection.logger.info('[TokensService][disposeIsolate] Done');
  }

  @override
  Future<void> purgeCachedGallery() async {
    disposeIsolate();
    await _configurationService.setDidSyncAddress(false);
    _database.clearAll();
  }

  @override
  Future<Stream<List<AssetToken>>> fetchTokensInIsolate(
    List<String> addresses,
  ) async {
    if (_currentAddresses != null) {
      if (listEquals(_currentAddresses, addresses)) {
        if (_refreshAllTokensWorker != null &&
            !_refreshAllTokensWorker!.isClosed) {
          NftCollection.logger
              .info('[refreshTokensInIsolate] skip because worker is running');
          return _refreshAllTokensWorker!.stream;
        }
      } else {
        NftCollection.logger
            .info('[refreshTokensInIsolate] dispose previous worker');
        disposeIsolate();
      }
    }

    NftCollection.logger.info('[refreshTokensInIsolate] start');
    await startIsolateOrWait();
    _currentAddresses = List.from(addresses);
    _refreshAllTokensWorker = StreamController<List<AssetToken>>();
    _sendPort?.send([
      FETCH_ALL_TOKENS,
      addresses,
    ]);

    NftCollection.logger.info('[FETCH_ALL_TOKENS][start]');

    return _refreshAllTokensWorker!.stream;
  }

  @override
  Future<TriggerIndexingResult> reindexAddresses(List<String> addresses) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final completer = Completer<TriggerIndexingResult>();
    _reindexAddressesCompleters[uuid] = completer;

    _sendPort?.send([REINDEX_ADDRESSES, uuid, addresses]);

    NftCollection.logger.fine('[reindexAddresses][start] $addresses');
    return completer.future;
  }

  @override
  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    Map<String, DateTime?> addressToSince,
  ) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final controller = StreamController<List<AssetToken>>();
    _streamControllers[uuid] = controller;

    final Map<String, String?> payload = addressToSince.map(
      (addr, dt) => MapEntry(addr, dt?.toUtc().toIso8601String()),
    );

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
    NftCollection.logger
        .info('[insertAssetsWithProvenance][tokens] $tokensLog');
  }

  @override
  Future<List<AssetToken>> fetchManualTokens(List<String> indexerIds) async {
    final request = QueryListTokensRequest(
      tokenIds: indexerIds,
      limit: indexerIds.length,
    );

    final manuallyAssets = await _indexerService.getNftTokens(request);

    NftCollection.logger.info('[TokensService] '
        'fetched ${manuallyAssets.length} manual tokens. '
        'IDs: $indexerIds');
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
    // get from database
    final assetTokenFromDatabase = _database.getTokensByCIDs(cids: cids);
    final res = [...assetTokenFromDatabase];
    final missingIds = cids
        .where((cid) => !assetTokenFromDatabase.any((e) => e.cid == cid))
        .toList();
    if (missingIds.isNotEmpty) {
      if (shouldCallIndexer) {
        final assetTokenFromIndexer = await fetchManualTokens(missingIds);
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
  }

  static void _isolateEntry(List<dynamic> arguments) {
    final sendPort = arguments[0] as SendPort;

    final receivePort = ReceivePort()..listen(_handleMessageInIsolate);
    _isolateSendPort = sendPort;

    _setupInjector(arguments[1] as String);
    sendPort.send(receivePort.sendPort);
  }

  static void _setupInjector(String indexerUrl) {
    // Register a proxy AuthService that communicates with main isolate.
    _isolateScopeInjector.registerLazySingleton<AuthServicePort>(
      () => RemoteAuthService(_isolateSendPort!),
    );

    // Build IndexerClient with token provider that calls back to main via proxy
    final authPort = _isolateScopeInjector<AuthServicePort>();
    final indexerClient = IndexerClient(
      indexerUrl,
      authService: null,
      getTokenOverride: () async {
        String? token;
        try {
          token = await authPort.getAccessTokenOrNull();
        } catch (e) {
          log.warning('[IndexerClient][isolate] getToken timeout/error: $e');
        }
        return (token != null && token.isNotEmpty) ? 'Bearer $token' : '';
      },
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

    // Handle auth bridge requests from worker isolate
    if (message is List && message.isNotEmpty && message[0] == AUTH_OP) {
      final String op = message[1] as String;
      final String reqId = message[2] as String;
      try {
        switch (op) {
          case AUTH_GET_TOKEN:
            final jwt = await injector<AuthService>()
                .getAuthToken(shouldRefresh: false);
            _sendPort?.send([AUTH_OP, reqId, null, jwt?.jwtToken]);
            break;
          case AUTH_REFRESH:
            final jwt = await injector<AuthService>().refreshJWT();
            _sendPort?.send([AUTH_OP, reqId, null, jwt.jwtToken]);
            break;
          default:
            _sendPort?.send([AUTH_OP, reqId, 'Unsupported auth op', null]);
        }
      } catch (e) {
        _sendPort?.send([AUTH_OP, reqId, e.toString(), null]);
      }
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
        if (_refreshAllTokensWorker != null &&
            !_refreshAllTokensWorker!.isClosed) {
          _refreshAllTokensWorker!.sink.add(result.assets);
        }

        if (result.done) {
          await _refreshAllTokensWorker?.close();
          NftCollection.logger.fine(
            '[FETCH_ALL_TOKENS]'
            ' ${result.addresses.join(',')} at ${DateTime.now()}',
          );
          NftCollection.logger.info('[FETCH_ALL_TOKENS][end]');
        }
      }

      return;
    }

    if (result is FetchTokenFailure) {
      NftCollection.logger
          .info('[FETCH_ALL_TOKENS] end in error ${result.exception}');

      if (result.key == FETCH_ALL_TOKENS) {
        await _refreshAllTokensWorker?.close();
      }
      return;
    }

    if (result is ReindexAddressesDone) {
      _reindexAddressesCompleters[result.uuid]?.complete(result.result);
      _reindexAddressesCompleters.remove(result.uuid);
      NftCollection.logger.info(
        '[reindexAddresses][end] workflowId: ${result.result.workflowId}, runId: ${result.result.runId}',
      );
    }

    if (result is ReindexAddressesFailure) {
      _reindexAddressesCompleters[result.uuid]?.completeError(result.exception);
      _reindexAddressesCompleters.remove(result.uuid);
      NftCollection.logger.info(
        '[reindexAddresses][error] ${result.uuid}: ${result.exception}',
      );
    }

    if (result is UpdateTokensSuccess) {
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        // Group changes by tokenCid
        final groupedChanges =
            result.changes.groupBy((change) => change.tokenCid);
        final cids = groupedChanges.keys.toList();

        // Get tokens from database
        final tokens = _database.getTokensByCIDs(cids: cids);
        final updatedTokens = <AssetToken>[];

        // Apply all changes to each token
        for (final tokenCid in groupedChanges.keys) {
          final changes = groupedChanges[tokenCid]!;

          // Find current token in database
          var currentToken =
              tokens.firstWhereOrNull((token) => token.cid == tokenCid);

          // Sort changes by changedAt to apply in chronological order
          final sortedChanges = changes.toList()
            ..sort((a, b) => a.changedAt.compareTo(b.changedAt));

          // Apply each change to the token
          for (final change in sortedChanges) {
            final meta = change.metaParsed;
            if (meta != null) {
              if (meta is ProvenanceChangeMeta) {
                if (meta.isMint()) {
                  // if the change is a mint, we need to fetch token from indexer, then insert into database
                  final cid = change.tokenCid;
                  final token = await _indexerService
                      .getTokenByCid(QueryGetTokenByCidRequest(cid: cid));
                  if (token != null) {
                    await insertAssetsWithProvenance([token]);
                    currentToken = token;
                  }
                } else if (meta.isBurn()) {
                  // if the change is a burn, we need to remove the token from database
                  final cid = change.tokenCid;
                  _database.deleteToken(cid);
                  currentToken = null;
                }
              }
              if (currentToken != null) {
                currentToken =
                    currentToken.applyChangeMeta(meta, change.changedAt);
              } else {
                NftCollection.logger.info(
                    "[UpdateTokensSuccess] token not found in database: $tokenCid, change: $change");
              }
            } else {
              log.info("[UpdateTokensSuccess] meta is null");
            }
          }

          if (currentToken != null) {
            updatedTokens.add(currentToken);
          }
        }

        // Insert updated tokens into database
        if (updatedTokens.isNotEmpty) {
          await insertAssetsWithProvenance(updatedTokens);
        }

        // Emit updated tokens to stream
        for (final token in updatedTokens) {
          controller.add([token]);
        }

        await controller.close();
        _streamControllers.remove(result.uuid);
        NftCollection.logger.info(
          '[UPDATE_TOKENS_IN_ISOLATE][end] ${result.uuid} - Updated ${updatedTokens.length} tokens',
        );
      }
    }
  }

  static SendPort? _isolateSendPort;

  static void _handleMessageInIsolate(dynamic message) {
    NftCollection.logger
        .info('[TokensService][Isolate] received message: $message');
    if (message is List<dynamic>) {
      switch (message[0]) {
        case AUTH_OP:
          if (message.length >= 4) {
            final String reqId = message[1] as String;
            final String? error = message[2] as String?;
            final dynamic data = message[3];
            final completer = _authRequestCompleters.remove(reqId);
            if (completer != null && !completer.isCompleted) {
              if (error != null) {
                completer.completeError(error);
              } else {
                completer.complete(data);
              }
            }
          }
          return;
        case FETCH_ALL_TOKENS:
          _fetchAllTokens(
            FETCH_ALL_TOKENS,
            const Uuid().v4(),
            List<String>.from(message[1] as List),
          );

        case REINDEX_ADDRESSES:
          _reindexAddressesInIndexer(
            message[1] as String,
            List<String>.from(message[2] as List),
          );

        case UPDATE_TOKENS_IN_ISOLATE:
          _updateTokensInIsolate(
            message[1] as String,
            Map<String, String?>.from(
              (message[2] as Map).map(
                (k, v) => MapEntry(k as String, v as String?),
              ),
            ),
          );
          break;

        default:
          break;
      }
    }
  }

  static Future<void> _fetchAllTokens(
    String key,
    String uuid,
    List<String> addresses,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      var offset = 0;

      do {
        final request = QueryListTokensRequest(
          owners: addresses,
          offset: offset,
        );

        final assets = await isolateIndexerService.getNftTokens(request);

        if (assets.isEmpty) {
          break;
        } else {
          _isolateSendPort?.send(
            FetchTokensSuccess(
              key,
              uuid,
              addresses,
              assets,
              false,
            ),
          );

          offset += assets.length;
        }
      } while (true);

      _isolateSendPort
          ?.send(FetchTokensSuccess(key, uuid, addresses, [], true));
    } catch (exception) {
      _isolateSendPort?.send(FetchTokenFailure(key, uuid, exception));
    }
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

  static Future<void> _updateTokensInIsolate(
    String uuid,
    Map<String, String?> addressToSinceIso,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      final List<Change> allChanges = [];

      // Fetch changes per address with its own since filter
      for (final entry in addressToSinceIso.entries) {
        final addr = entry.key;
        final sinceIso = entry.value;
        final changes = await _getChangesForAddress(
          isolateIndexerService,
          addr,
          sinceIso,
        );
        allChanges.addAll(changes);
      }

      // Send all changes to main isolate to fetch tokens from database
      _isolateSendPort?.send(
        UpdateTokensSuccess(uuid, allChanges),
      );
    } catch (exception) {
      _isolateSendPort?.send(UpdateTokensFailure(uuid, exception));
    }
  }

  static Future<List<Change>> _getChangesForAddress(
    NftIndexerService service,
    String address,
    String? sinceIso,
  ) async {
    var offset = 0;
    const pageSize = 50;
    final List<Change> acc = [];

    while (true) {
      final req = QueryChangesRequest(
        addresses: [address],
        since: sinceIso,
        limit: pageSize,
        offset: offset,
      );
      final page = await service.getChanges(req);
      if (page.items.isEmpty) break;
      acc.addAll(page.items);
      offset += page.items.length;
      if (page.items.length < pageSize) break;
    }

    return acc;
  }
}

class AddressSince {
  AddressSince({required this.address, required this.lastUpdatedAt});

  final String address;
  final DateTime? lastUpdatedAt;

  Map<String, dynamic> toJson() => {
        'address': address,
        'since_iso': lastUpdatedAt?.toUtc().toIso8601String(),
      };

  static AddressSince fromJson(Map<String, dynamic> json) => AddressSince(
        address: json['address'] as String,
        lastUpdatedAt: (json['since_iso'] as String?) != null
            ? DateTime.tryParse(json['since_iso'] as String)
            : null,
      );
}

abstract class TokensServiceResult {}

// A minimal port of AuthService behavior that is safe across isolates.
abstract class AuthServicePort {
  Future<String?> getAccessTokenOrNull();
  Future<String?> refreshToken();
}

// Track pending auth requests in the worker isolate
final Map<String, Completer<dynamic>> _authRequestCompleters = {};

class RemoteAuthService implements AuthServicePort {
  RemoteAuthService(this._mainSendPort);

  final SendPort _mainSendPort;

  Future<T?> _call<T>(String op) async {
    final reqId = const Uuid().v4();
    final completer = Completer<dynamic>();
    _authRequestCompleters[reqId] = completer;
    _mainSendPort.send([AUTH_OP, op, reqId]);
    final result = await completer.future;
    return result as T?;
  }

  @override
  Future<String?> getAccessTokenOrNull() => _call<String?>(AUTH_GET_TOKEN);

  @override
  Future<String?> refreshToken() => _call<String?>(AUTH_REFRESH);
}

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
  FetchTokenFailure(this.uuid, this.key, this.exception);

  final String uuid;
  final String key;
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

class UpdateTokensSuccess extends TokensServiceResult {
  UpdateTokensSuccess(this.uuid, this.changes);

  final String uuid;
  final List<Change> changes;
}

class UpdateTokensFailure extends TokensServiceResult {
  UpdateTokensFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
}
