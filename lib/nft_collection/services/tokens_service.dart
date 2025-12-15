//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:autonomy_flutter/nft_collection/data/api/indexer_api.dart';
import 'package:autonomy_flutter/nft_collection/data/api/tzkt_api.dart';
import 'package:autonomy_flutter/nft_collection/database/dao/dao.dart';
import 'package:autonomy_flutter/nft_collection/database/nft_collection_database.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/models/asset.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/pending_tx_params.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:autonomy_flutter/nft_collection/models/token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/address_service.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/logging_interceptor.dart';
import 'package:uuid/uuid.dart';

abstract class TokensService {
  Future<void> fetchTokensForAddresses(List<String> addresses);

  Future<List<AssetToken>> fetchManualTokens(List<String> indexerIds);

  Future<void> setCustomTokens(List<AssetToken> assetTokens);

  Future<Stream<List<AssetToken>>> refreshTokensInIsolate(
    Map<int, List<String>> addresses,
  );

  Future<void> reindexAddresses(List<String> addresses);

  bool get isRefreshAllTokensListen;

  Future<void> purgeCachedGallery();

  Future<void> postPendingToken(PendingTxParams params);
}

final _isolateScopeInjector = GetIt.asNewInstance();

class TokensServiceImpl extends TokensService {
  TokensServiceImpl(
    this._indexerUrl,
    this._database,
    this._configurationService,
    this._addressService, [
    Dio? dio,
  ]) {
    dio ??= Dio()..interceptors.add(LoggingInterceptor());
    final indexerClient = IndexerClient(_indexerUrl);
    _indexerService = IndexerService(indexerClient);
  }

  final String _indexerUrl;
  late IndexerService _indexerService;
  final NftCollectionDatabase _database;
  final NftCollectionPrefs _configurationService;
  final AddressService _addressService;

  static const REFRESH_ALL_TOKENS = 'REFRESH_ALL_TOKENS';
  static const FETCH_TOKENS = 'FETCH_TOKENS';
  static const REINDEX_ADDRESSES = 'REINDEX_ADDRESSES';

  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  var _isolateReady = Completer<void>();
  List<String>? _currentAddresses;
  StreamController<List<AssetToken>>? _refreshAllTokensWorker;

  @override
  bool get isRefreshAllTokensListen =>
      _refreshAllTokensWorker?.hasListener ?? false;
  Map<String, Completer<void>> _fetchTokensCompleters = {};
  final Map<String, Completer<void>> _reindexAddressesCompleters = {};

  Future<void> get isolateReady => _isolateReady.future;

  TokenDao get _tokenDao => _database.tokenDao;

  AssetDao get _assetDao => _database.assetDao;

  AssetTokenDao get _assetTokenDao => _database.assetTokenDao;

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
    _isolate?.kill();
    _isolateSendPort = null;
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _currentAddresses = null;
    _isolateReady = Completer<void>();
    _fetchTokensCompleters = {};
    NftCollection.logger.info('[TokensService][disposeIsolate] Done');
  }

  @override
  Future<void> purgeCachedGallery() async {
    disposeIsolate();
    await _configurationService.setDidSyncAddress(false);
    await _database.removeAll();
  }

  Future<List<String>> _getPendingTokenIds() async {
    return (await _tokenDao.findAllPendingTokens()).map((e) => e.id).toList();
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

    final pendingTokens = await _getPendingTokenIds();
    NftCollection.logger.info('[refreshTokensInIsolate] Pending tokens: '
        '$pendingTokens');

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

  Future<void> insertAssetsWithProvenance(List<AssetToken> assetTokens) async {
    final tokens = <Token>[];
    final assets = <Asset>[];
    final provenance = <Provenance>[];

    for (final assetToken in assetTokens) {
      final token = Token.fromAssetToken(assetToken);
      tokens.add(token);
      final asset = assetToken.projectMetadata?.toAsset;
      if (asset != null) {
        assets.add(asset);
      }
      provenance.addAll(assetToken.provenance);
    }

    final tokensLog =
        tokens.map((e) => 'id: ${e.id} balance: ${e.balance} ').toList();
    await _tokenDao.insertTokens(tokens);
    NftCollection.logger
        .info('[insertAssetsWithProvenance][tokens] $tokensLog');

    await _assetDao.insertAssets(assets);
    await _database.provenanceDao.insertProvenance(provenance);
  }

  @override
  Future<void> fetchTokensForAddresses(List<String> addresses) async {
    await startIsolateOrWait();

    final uuid = const Uuid().v4();
    final completer = Completer<void>();
    _fetchTokensCompleters[uuid] = completer;

    _sendPort!.send([
      FETCH_TOKENS,
      uuid,
      {0: addresses},
    ]);
    NftCollection.logger.fine('[FETCH_TOKENS][start] $addresses');

    return completer.future;
  }

  @override
  Future<List<AssetToken>> fetchManualTokens(List<String> indexerIds) async {
    final request = QueryListTokensRequest(
      ids: indexerIds,
    );

    final manuallyAssets = await _indexerService.getNftTokens(request);

    //stripe owner for manual asset
    for (var i = 0; i < manuallyAssets.length; i++) {
      manuallyAssets[i].owner = '';
      manuallyAssets[i].isManual = true;
    }

    NftCollection.logger.info('[TokensService] '
        'fetched ${manuallyAssets.length} manual tokens. '
        'IDs: $indexerIds');
    if (manuallyAssets.isNotEmpty) {
      await insertAssetsWithProvenance(manuallyAssets);
    }
    return manuallyAssets;
  }

  @override
  Future<void> setCustomTokens(List<AssetToken> assetTokens) async {
    try {
      final tokens = assetTokens.map(Token.fromAssetToken).toList();
      final assets = assetTokens
          .where((element) => element.asset != null)
          .map((e) => e.asset!)
          .toList();
      await _tokenDao.insertTokensAbort(tokens);
      await _assetDao.insertAssetsAbort(assets);
    } catch (e) {
      NftCollection.logger.info('[TokensService] '
          'setCustomTokens '
          'error: $e');
    }
  }

  @override
  Future<void> postPendingToken(PendingTxParams params) async {}

  static void _isolateEntry(List<dynamic> arguments) {
    final sendPort = arguments[0] as SendPort;

    final receivePort = ReceivePort()..listen(_handleMessageInIsolate);

    _setupInjector(arguments[1] as String);
    sendPort.send(receivePort.sendPort);
    _isolateSendPort = sendPort;
  }

  static void _setupInjector(String indexerUrl) {
    final dio = Dio();
    dio.interceptors.add(LoggingInterceptor());
    _isolateScopeInjector
        .registerLazySingleton(() => IndexerApi(dio, baseUrl: indexerUrl));
    final indexerClient = IndexerClient(indexerUrl);
    _isolateScopeInjector
      ..registerLazySingleton(() => indexerClient)
      ..registerLazySingleton(
        () => IndexerService(indexerClient),
      )
      ..registerLazySingleton(() => TZKTApi(dio));
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

      if (result.key == REFRESH_ALL_TOKENS) {
        if (_refreshAllTokensWorker != null &&
            !_refreshAllTokensWorker!.isClosed) {
          _refreshAllTokensWorker!.sink.add(result.assets);
        }

        if (result.done) {
          await _refreshAllTokensWorker?.close();
          final lastRefreshedTime = await _assetTokenDao.getLastRefreshedTime();
          await _addressService.updateRefreshedTime(
            result.addresses,
            lastRefreshedTime ?? DateTime.fromMillisecondsSinceEpoch(0),
          );
          NftCollection.logger.fine(
            '[REFRESH_ALL_TOKENS]'
            ' ${result.addresses.join(',')} at ${DateTime.now()}',
          );
          NftCollection.logger.info('[REFRESH_ALL_TOKENS][end]');
        }
      }
      if (result.key == FETCH_TOKENS) {
        if (result.done) {
          _fetchTokensCompleters[result.uuid]?.complete();
          _fetchTokensCompleters.remove(result.uuid);
          NftCollection.logger.info('[FETCH_TOKENS][end]');
        }
      }

      return;
    }

    if (result is FetchTokenFailure) {
      NftCollection.logger
          .info('[REFRESH_ALL_TOKENS] end in error ${result.exception}');

      if (result.key == REFRESH_ALL_TOKENS) {
        await _refreshAllTokensWorker?.close();
      } else if (result.key == FETCH_TOKENS) {
        _fetchTokensCompleters[result.uuid]?.completeError(result.exception);
        _fetchTokensCompleters.remove(result.uuid);
      }
      return;
    }

    if (result is ReindexAddressesDone) {
      _reindexAddressesCompleters[result.uuid]?.complete();
      _fetchTokensCompleters.remove(result.uuid);
      NftCollection.logger.info('[reindexAddresses][end]');
    }
  }

  static SendPort? _isolateSendPort;

  static void _handleMessageInIsolate(dynamic message) {
    if (message is List<dynamic>) {
      switch (message[0]) {
        case REFRESH_ALL_TOKENS:
          _refreshAllTokens(
            REFRESH_ALL_TOKENS,
            const Uuid().v4(),
            Map<int, dynamic>.from(message[1] as Map).map(
              (key, value) => MapEntry(key, List<String>.from(value as List)),
            ),
          );

        case FETCH_TOKENS:
          _refreshAllTokens(
            FETCH_TOKENS,
            message[1] as String,
            Map<int, dynamic>.from(message[2] as Map).map(
              (key, value) => MapEntry(key, List<String>.from(value as List)),
            ),
          );

        case REINDEX_ADDRESSES:
          _reindexAddressesInIndexer(
            message[1] as String,
            List<String>.from(message[2] as List),
          );

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
      final isolateIndexerService = _isolateScopeInjector<IndexerService>();
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
              lastUpdatedAt: lastRefreshedTime != 0
                  ? DateTime.fromMillisecondsSinceEpoch(lastRefreshedTime)
                  : null,
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
    String uuid,
    List<String> addresses, {
    bool history = true,
  }) async {
    final indexerAPI = _isolateScopeInjector<IndexerApi>();
    for (final address in addresses) {
      if (address.startsWith('tz') || address.startsWith('0x')) {
        await indexerAPI.requestIndex({'owner': address, 'history': history});
      }
    }
    _isolateSendPort?.send(ReindexAddressesDone(uuid));
  }
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
  FetchTokenFailure(this.uuid, this.key, this.exception);

  final String uuid;
  final String key;
  final Object exception;
}

class ReindexAddressesDone extends TokensServiceResult {
  ReindexAddressesDone(this.uuid);

  final String uuid;
}
