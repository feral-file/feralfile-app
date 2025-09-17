//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:isolate';

import 'package:autonomy_flutter/nft_collection/data/api/indexer_api.dart';
import 'package:autonomy_flutter/nft_collection/data/api/tzkt_api.dart';
import 'package:autonomy_flutter/nft_collection/database/dao/dao.dart';
import 'package:autonomy_flutter/nft_collection/database/nft_collection_database.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/artblocks_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/models/asset.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';
import 'package:autonomy_flutter/nft_collection/models/token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/address_service.dart';
import 'package:autonomy_flutter/nft_collection/services/artblocks_service.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/logging_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

abstract class NftTokensService {
  Future<void> fetchTokensForAddresses(List<String> addresses);

  Future<List<AssetToken>> fetchManualTokens(List<String> indexerIds);

  Future<List<AssetToken>> getManualTokens(
      {required List<String> indexerIds, bool shouldCallIndexer = true});

  Future<void> setCustomTokens(List<AssetToken> assetTokens);

  Future<Stream<List<AssetToken>>> refreshTokensInIsolate(
    Map<int, List<String>> addresses,
  );

  Future<Stream<List<AssetToken>>> getAssetTokensStream(
    List<String> addresses, {
    int pageSize = 50,
    DateTime? lastUpdatedAt,
  });

  Future<void> reindexAddresses(List<String> addresses);

  bool get isRefreshAllTokensListen;

  Future<void> purgeCachedGallery();
}

final _isolateScopeInjector = GetIt.asNewInstance();

class NftTokensServiceImpl extends NftTokensService {
  NftTokensServiceImpl(
    this._indexerUrl,
    this._database,
    this._configurationService,
    this._addressService, [
    Dio? dio,
  ]) {
    dio ??= Dio()..interceptors.add(LoggingInterceptor());
    _indexer = IndexerApi(dio, baseUrl: _indexerUrl);
    final indexerClient = IndexerClient(_indexerUrl);
    final artblocksClient = ArtblocksClient();
    final artBlockService = ArtBlockService(artblocksClient);
    _indexerService =
        NftIndexerService(indexerClient, _indexer, artBlockService);
  }

  final String _indexerUrl;
  late IndexerApi _indexer;
  late NftIndexerService _indexerService;
  final NftCollectionDatabase _database;
  final NftCollectionPrefs _configurationService;
  final NftAddressService _addressService;

  static const REFRESH_ALL_TOKENS = 'REFRESH_ALL_TOKENS';
  static const FETCH_TOKENS = 'FETCH_TOKENS';
  static const REINDEX_ADDRESSES = 'REINDEX_ADDRESSES';
  static const GET_ASSET_TOKENS_STREAM = 'GET_ASSET_TOKENS_STREAM';

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
  final Map<String, StreamController<List<AssetToken>>> _streamControllers = {};

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
    _fetchTokensCompleters = {};
    NftCollection.logger.info('[TokensService][disposeIsolate] Done');
  }

  @override
  Future<void> purgeCachedGallery() async {
    disposeIsolate();
    await _configurationService.setDidSyncAddress(false);
    await _database.removeAll();
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
  Future<Stream<List<AssetToken>>> getAssetTokensStream(
    List<String> addresses, {
    int pageSize = 50,
    DateTime? lastUpdatedAt,
  }) async {
    if (addresses.isEmpty) {
      return Stream.value([]);
    }

    await startIsolateOrWait();

    final streamController = StreamController<List<AssetToken>>();
    final uuid = const Uuid().v4();

    // Store the stream controller for cleanup
    _streamControllers[uuid] = streamController;

    // Send message to isolate to start streaming
    _sendPort?.send([
      GET_ASSET_TOKENS_STREAM,
      uuid,
      addresses,
      pageSize,
      lastUpdatedAt?.millisecondsSinceEpoch,
    ]);

    return streamController.stream;
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
      final assetToken = manuallyAssets[i];
      final newAssetToken = assetToken.copyWith(owner: '', isManual: true);
      manuallyAssets[i] = newAssetToken;
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
  Future<List<AssetToken>> getManualTokens(
      {required List<String> indexerIds, bool shouldCallIndexer = true}) async {
    // get from database
    final assetTokenFromDatabase =
        await _assetTokenDao.findAllAssetTokensByTokenIDs(indexerIds);
    final res = [...assetTokenFromDatabase];
    final missingIds = indexerIds
        .where((id) => !assetTokenFromDatabase.any((e) => e.id == id))
        .toList();
    if (missingIds.isNotEmpty) {
      if (shouldCallIndexer) {
        final assetTokenFromIndexer = await fetchManualTokens(missingIds);
        res.addAll(assetTokenFromIndexer);
      }
    }
    // reorder the res to match the indexerIds
    res.sort(
      (a, b) => indexerIds.indexOf(a.id).compareTo(
            indexerIds.indexOf(b.id),
          ),
    );
    return res;
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
    final artblocksClient = ArtblocksClient();
    final artBlockService = ArtBlockService(artblocksClient);
    _isolateScopeInjector
      ..registerLazySingleton(() => indexerClient)
      ..registerLazySingleton(() => artBlockService)
      ..registerLazySingleton(
        () => NftIndexerService(indexerClient,
            _isolateScopeInjector<IndexerApi>(), artBlockService),
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

    if (result is StreamTokensSuccess) {
      final controller = _streamControllers[result.uuid];
      if (controller != null && !controller.isClosed) {
        controller.add(result.assets);

        if (result.done) {
          controller.close();
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
        controller.close();
        _streamControllers.remove(result.uuid);
        NftCollection.logger.info(
            '[GET_ASSET_TOKENS_STREAM][error] ${result.uuid}: ${result.exception}');
      }
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

        case GET_ASSET_TOKENS_STREAM:
          _getAssetTokensStreamInIsolate(
            message[1] as String,
            List<String>.from(message[2] as List),
            message[3] as int,
            message[4] != null
                ? DateTime.fromMillisecondsSinceEpoch(message[4] as int)
                : null,
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

  static Future<void> _getAssetTokensStreamInIsolate(
    String uuid,
    List<String> addresses,
    int pageSize,
    DateTime? lastUpdatedAt,
  ) async {
    try {
      final isolateIndexerService = _isolateScopeInjector<NftIndexerService>();
      int offset = 0;
      bool hasMoreData = true;

      while (hasMoreData) {
        final request = QueryListTokensRequest(
          owners: addresses,
          offset: offset,
          size: pageSize,
          lastUpdatedAt: lastUpdatedAt,
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

class StreamTokensSuccess extends TokensServiceResult {
  StreamTokensSuccess(
    this.uuid,
    this.assets,
    this.done,
  );

  final String uuid;
  final List<AssetToken> assets;
  final bool done;
}

class StreamTokensFailure extends TokensServiceResult {
  StreamTokensFailure(this.uuid, this.exception);

  final String uuid;
  final Object exception;
}
