//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: cascade_invocations

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/gateway/feralfile_api.dart';
import 'package:autonomy_flutter/gateway/remote_config_api.dart';
import 'package:autonomy_flutter/gateway/source_exhibition_api.dart';
import 'package:autonomy_flutter/nft_collection/data/api/indexer_api.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/ethereum_service.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/network_issue_manager.dart';
import 'package:autonomy_flutter/service/network_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/au_file_service.dart';
import 'package:autonomy_flutter/util/dio_util.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

final injector = GetIt.instance;
final testnetInjector = GetIt.asNewInstance();

const iapApiTimeout5secInstanceName = 'iapApiTimeout5sec';

Future<void> setupLogger() async {
  await FileLogger.initializeLogging();

  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    try {
      FileLogger.log(record);
      SentryBreadcrumbLogger.log(record);
    } catch (e, s) {
      Sentry.captureException('Error logging record: $e', stackTrace: s);
    }
  });
}

Future<void> setupInjector() async {
  final sharedPreferences = await SharedPreferences.getInstance();

  injector.registerLazySingleton(NavigationService.new);

  injector.registerLazySingleton<NetworkIssueManager>(NetworkIssueManager.new);

  final dioOptions = BaseOptions(
    followRedirects: true,
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  );
  final dio = baseDio(dioOptions);

  await NftCollection.initNftCollection(
    indexerUrl: Environment.indexerURL,
    logger: log,
    apiLogger: apiLog,
    dio: dio,
  );
  injector
      .registerLazySingleton<TokensService>(() => NftCollection.tokenService);
  injector.registerLazySingleton(() => NftCollection.prefs);
  injector.registerLazySingleton(() => NftCollection.database);
  injector.registerLazySingleton(() => NftCollection.addressService);
  injector.registerLazySingleton(() => NftCollection.database.assetDao);
  injector.registerLazySingleton(() => NftCollection.database.tokenDao);
  injector.registerLazySingleton(() => NftCollection.database.assetTokenDao);
  injector.registerLazySingleton(() => NftCollection.database.provenanceDao);
  injector.registerLazySingleton(
    () => NftCollection.database.predefinedCollectionDao,
  );

  injector.registerLazySingleton<NetworkService>(NetworkService.new);
  // Services

  injector.registerSingleton<ConfigurationService>(
    ConfigurationServiceImpl(sharedPreferences),
  );
  injector.registerLazySingleton(http.Client.new);
  injector.registerLazySingleton<CacheManager>(AUImageCacheManage.new);

  injector.registerLazySingleton(
    () => SourceExhibitionAPI(dio, baseUrl: Environment.pubdocURL),
  );
  injector.registerLazySingleton<RemoteConfigService>(
    () => RemoteConfigServiceImpl(
      RemoteConfigApi(dio, baseUrl: Environment.remoteConfigURL),
    ),
  );

  injector.registerLazySingleton(
    () => Web3Client(Environment.web3RpcURL, injector()),
  );

  injector.registerLazySingleton<FeralFileApi>(
    () => FeralFileApi(
      feralFileDio(dioOptions),
      baseUrl: Environment.feralFileAPIURL,
    ),
  );
  injector.registerLazySingleton<IndexerApi>(
    () => IndexerApi(dio, baseUrl: Environment.indexerURL),
  );

  final indexerClient = IndexerClient(Environment.indexerURL);
  injector.registerLazySingleton<IndexerService>(
    () => IndexerService(indexerClient),
  );

  injector.registerLazySingleton<EthereumService>(
    () => EthereumServiceImpl(
      injector(),
      injector(),
    ),
  );

  injector.registerLazySingleton<FeralFileService>(
    () => FeralFileServiceImpl(
      injector(),
      injector(),
    ),
  );

  final identityStore = IndexerIdentityStore();
  await identityStore.init('');
  injector.registerLazySingleton<IdentityBloc>(
    () => IdentityBloc(identityStore, injector()),
  );
}
