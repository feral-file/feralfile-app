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

  Future<Stream<List<AssetToken>>> refreshTokensInIsolate(
    Map<int, List<String>> addresses,
  );

  Future<void> reindexAddresses(List<String> addresses);

  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    List<String> addresses,
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

  static const REFRESH_ALL_TOKENS = 'REFRESH_ALL_TOKENS';
  static const REINDEX_ADDRESSES = 'REINDEX_ADDRESSES';
  static const GET_ASSET_TOKENS_STREAM = 'GET_ASSET_TOKENS_STREAM';
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
  final Map<String, Completer<void>> _reindexAddressesCompleters = {};
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
  Future<Stream<List<AssetToken>>> refreshTokensInIsolate(
    Map<int, List<String>> addresses,
  ) async {
    final inputAddresses = addresses.values.expand((list) => list).toList();
    if (_currentAddresses != null) {
      if (listEquals(_currentAddresses, inputAddresses)) {
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
    _currentAddresses = List.from(inputAddresses);
    _refreshAllTokensWorker = StreamController<List<AssetToken>>();
    _sendPort?.send([
      REFRESH_ALL_TOKENS,
      addresses,
    ]);

    NftCollection.logger.info('[REFRESH_ALL_TOKENS][start]');

    _currentAddresses = List.from(inputAddresses);

    return _refreshAllTokensWorker!.stream;
  }

  @override
  Future<void> reindexAddresses(List<String> addresses) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final completer = Completer<dynamic>();
    _reindexAddressesCompleters[uuid] = completer;

    _sendPort?.send([REINDEX_ADDRESSES, uuid, addresses]);

    NftCollection.logger.fine('[reindexAddresses][start] $addresses');
    return completer.future;
  }

  @override
  Future<Stream<List<AssetToken>>> updateTokensInIsolate(
    List<String> addresses,
  ) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final controller = StreamController<List<AssetToken>>();
    _streamControllers[uuid] = controller;

    _sendPort?.send([UPDATE_TOKENS_IN_ISOLATE, uuid, addresses]);

    NftCollection.logger.info('[updateTokensInIsolate][start] $addresses');
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

      if (result.key == REFRESH_ALL_TOKENS) {
        if (_refreshAllTokensWorker != null &&
            !_refreshAllTokensWorker!.isClosed) {
          _refreshAllTokensWorker!.sink.add(result.assets);
        }

        if (result.done) {
          await _refreshAllTokensWorker?.close();
          NftCollection.logger.fine(
            '[REFRESH_ALL_TOKENS]'
            ' ${result.addresses.join(',')} at ${DateTime.now()}',
          );
          NftCollection.logger.info('[REFRESH_ALL_TOKENS][end]');
        }
      }

      return;
    }

    if (result is FetchTokenFailure) {
      NftCollection.logger
          .info('[REFRESH_ALL_TOKENS] end in error ${result.exception}');

      if (result.key == REFRESH_ALL_TOKENS) {
        await _refreshAllTokensWorker?.close();
      }
      return;
    }

    if (result is ReindexAddressesDone) {
      _reindexAddressesCompleters[result.uuid]?.complete();
      NftCollection.logger.info('[reindexAddresses][end]');
    }

    if (result is StreamTokensSuccess) {
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        controller.add(result.tokens);

        if (result.done) {
          await controller.close();
          _streamControllers.remove(result.uuid);
          NftCollection.logger
              .info('[GET_ASSET_TOKENS_STREAM][end] ${result.uuid}');
        }
      }
    }

    if (result is StreamTokensFailure) {
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        controller.addError(result.exception);
        await controller.close();
        _streamControllers.remove(result.uuid);
        NftCollection.logger.info(
          '[GET_ASSET_TOKENS_STREAM][error] ${result.uuid}: ${result.exception}',
        );
      }
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
          if (currentToken == null) {
            // Token not found in database, skip
            continue;
          }

          // Sort changes by changedAt to apply in chronological order
          final sortedChanges = changes.toList()
            ..sort((a, b) => a.changedAt.compareTo(b.changedAt));

          // Apply each change to the token
          for (final change in sortedChanges) {
            final meta = change.metaParsed;
            if (meta != null) {
              currentToken =
                  currentToken!.applyChangeMeta(meta, change.changedAt);
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
        case REFRESH_ALL_TOKENS:
          _refreshAllTokens(
            REFRESH_ALL_TOKENS,
            const Uuid().v4(),
            Map<int, dynamic>.from(message[1] as Map).map(
              (key, value) => MapEntry(key, List<String>.from(value as List)),
            ),
          );

        case REINDEX_ADDRESSES:
          _reindexAddressesInIndexer(
            message[1] as String,
            List<String>.from(message[2] as List),
          );

        case GET_ASSET_TOKENS_STREAM:
          _getAssetTokensStreamInIsolate(
            message[1] as String,
            List<String>.from(message[2] as List),
            message[3] as int,
            message[4] != null
                ? DateTime.fromMillisecondsSinceEpoch(message[4] as int)
                : null,
          );
          break;

        case UPDATE_TOKENS_IN_ISOLATE:
          _updateTokensInIsolate(
            message[1] as String,
            List<String>.from(message[2] as List),
          );
          break;

        default:
          break;
      }
    }
  }

  static Future<void> _refreshAllTokens(
    String key,
    String uuid,
    Map<int, List<String>> addresses,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      final offsetMap = addresses.map((key, value) => MapEntry(key, 0));

      await Future.wait(
        addresses.keys.map((lastRefreshedTime) async {
          if (addresses[lastRefreshedTime]?.isEmpty ?? true) return;
          final owners = addresses[lastRefreshedTime]?.join(',');
          if (owners == null) return;

          do {
            final request = QueryListTokensRequest(
              owners: addresses[lastRefreshedTime] ?? [],
              offset: offsetMap[lastRefreshedTime] ?? 0,
              // lastUpdatedAt: lastRefreshedTime != 0
              //     ? DateTime.fromMillisecondsSinceEpoch(lastRefreshedTime)
              //     : null,
            );

            final assets = await isolateIndexerService.getNftTokens(request);

            if (assets.isEmpty) {
              offsetMap.remove(lastRefreshedTime);
            } else {
              _isolateSendPort?.send(
                FetchTokensSuccess(
                  key,
                  uuid,
                  addresses[lastRefreshedTime]!,
                  assets,
                  false,
                ),
              );

              offsetMap[lastRefreshedTime] =
                  (offsetMap[lastRefreshedTime] ?? 0) + assets.length;
            }
          } while (offsetMap[lastRefreshedTime] != null);
        }),
      );
      final inputAddresses = addresses.values.expand((list) => list).toList();

      _isolateSendPort
          ?.send(FetchTokensSuccess(key, uuid, inputAddresses, [], true));
    } catch (exception) {
      _isolateSendPort?.send(FetchTokenFailure(key, uuid, exception));
    }
  }

  static Future<void> _reindexAddressesInIndexer(
      String uuid, List<String> addresses) async {
    final indexerService = _isolateScopeInjector<NftIndexerService>();
    for (final address in addresses) {
      if (address.startsWith('tz') || address.startsWith('0x')) {
        await indexerService.indexAddresses([address]);
      }
    }
    _isolateSendPort?.send(ReindexAddressesDone(uuid));
  }

  static Future<void> _getAssetTokensStreamInIsolate(
    String uuid,
    List<String> addresses,
    int pageSize,
    DateTime? lastUpdatedAt,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      var offset = 0;
      var hasMoreData = true;

      while (hasMoreData) {
        final request = QueryListTokensRequest(
          owners: addresses,
          offset: offset,
          limit: pageSize,
          // lastUpdatedAt: lastUpdatedAt,
        );

        final tokens = await isolateIndexerService.getNftTokens(request);

        if (tokens.isEmpty) {
          hasMoreData = false;
        } else {
          _isolateSendPort?.send(
            StreamTokensSuccess(
              uuid,
              tokens,
              false,
            ),
          );

          offset += tokens.length;

          // If we got fewer tokens than requested, we've reached the end
          if (tokens.length < pageSize) {
            hasMoreData = false;
          }
        }
      }

      // Send completion signal
      _isolateSendPort?.send(
        StreamTokensSuccess(
          uuid,
          [],
          true,
        ),
      );
    } catch (exception) {
      _isolateSendPort?.send(StreamTokensFailure(uuid, exception));
    }
  }

  static Future<void> _updateTokensInIsolate(
    String uuid,
    List<String> addresses,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      var offset = 0;
      var hasMoreData = true;
      final List<Change> allChanges = [];

      while (hasMoreData) {
        final request = QueryChangesRequest(
          addresses: addresses,
          offset: offset,
          limit: 50,
        );

        final changeList = await isolateIndexerService.getChanges(request);

        if (changeList.items.isEmpty) {
          hasMoreData = false;
        } else {
          allChanges.addAll(changeList.items);
          offset += changeList.items.length;

          // If we got fewer items than requested, we've reached the end
          if (changeList.items.length < 50) {
            hasMoreData = false;
          }
        }
      }

      // Send all changes to main isolate to fetch tokens from database
      _isolateSendPort?.send(
        UpdateTokensSuccess(uuid, allChanges),
      );
    } catch (exception) {
      _isolateSendPort?.send(StreamTokensFailure(uuid, exception));
    }
  }
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
  ReindexAddressesDone(this.uuid);

  final String uuid;
}

class StreamTokensSuccess extends TokensServiceResult {
  StreamTokensSuccess(
    this.uuid,
    this.tokens,
    this.done,
  );

  final String uuid;
  final List<AssetToken> tokens;
  final bool done;
}

class StreamTokensFailure extends TokensServiceResult {
  StreamTokensFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
}

class UpdateTokensSuccess extends TokensServiceResult {
  UpdateTokensSuccess(this.uuid, this.changes);

  final String uuid;
  final List<Change> changes;
}
