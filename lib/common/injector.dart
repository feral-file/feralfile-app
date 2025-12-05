//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: cascade_invocations

import 'package:autonomy_flutter/common/database.dart';
import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/database/hive_database.dart';
import 'package:autonomy_flutter/gateway/customer_support_api.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/gateway/feralfile_api.dart';
import 'package:autonomy_flutter/gateway/feralfile_docs_api.dart';
import 'package:autonomy_flutter/gateway/mobile_controller_api.dart';
import 'package:autonomy_flutter/gateway/pubdoc_api.dart';
import 'package:autonomy_flutter/gateway/remote_config_api.dart';
import 'package:autonomy_flutter/gateway/tv_cast_api.dart';
import 'package:autonomy_flutter/nft_collection/data/api/tzkt_api.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/works/bloc/works_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/service/announcement/announcement_store.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/service/dls_service.dart';
import 'package:autonomy_flutter/service/domain_address_service.dart';
import 'package:autonomy_flutter/service/domain_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/ethereum_service.dart';
import 'package:autonomy_flutter/service/feed_registry_service.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/meilisearch_service.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/network_issue_manager.dart';
import 'package:autonomy_flutter/service/network_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/secure_storage_server.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/util/au_file_service.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
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

  // Setup NFT collection dependencies
  // setupNftCollectionDependencies();

  injector.registerLazySingleton<NetworkIssueManager>(NetworkIssueManager.new);

  final dioOptions = BaseOptions(
    followRedirects: true,
    connectTimeout: const Duration(seconds: 3),
    receiveTimeout: const Duration(seconds: 3),
  );
  final dio = DioManager().base(dioOptions);

  // Initialize ObjectBox store only if not already initialized
  if (!ObjectBox.isInitialized) {
    await ObjectBox.create();
  }

  injector.registerLazySingleton<NetworkService>(NetworkService.new);
  // Services

  injector.registerSingleton<ConfigurationService>(
    ConfigurationServiceImpl(sharedPreferences),
  );
  injector.registerLazySingleton(http.Client.new);
  injector.registerLazySingleton<CacheManager>(AUImageCacheManage.new);

  injector.registerLazySingleton<HiveDatabase>(
    HiveDatabase.new,
  );

  injector.registerLazySingleton<AddressService>(
    () => AddressService(injector()),
  );

  final tzktUrl = Environment.appTestnetConfig
      ? Environment.tzktTestnetURL
      : Environment.tzktMainnetURL;
  injector.registerLazySingleton(() => TZKTApi(dio, baseUrl: tzktUrl));
  injector.registerLazySingleton(
    () => PubdocAPI(dio, baseUrl: Environment.pubdocURL),
  );
  injector.registerLazySingleton(
    () => FeralFileDocsAPI(dio, baseUrl: Environment.feralfileDocsURL),
  );

  injector.registerLazySingleton<RemoteConfigService>(
    () => RemoteConfigServiceImpl(
      RemoteConfigApi(dio, baseUrl: Environment.remoteConfigURL),
    ),
  );

  await NftCollection.initNftCollection(
    indexerUrl: Environment.indexerURL,
    logger: log,
    apiLogger: apiLog,
  );
  injector.registerLazySingleton<NftTokensService>(
    () => NftCollection.tokenService,
  );
  injector.registerLazySingleton(() => NftCollection.prefs);
  injector.registerLazySingleton<IndexerDatabaseAbstract>(
    () => NftCollection.database,
  );

  injector.registerLazySingleton<FFBluetoothService>(
    FFBluetoothService.new,
  );

  injector<FFBluetoothService>().startListen();

  injector.registerLazySingleton(
    () => TvCastApi(
      DioManager().tvCast(
        dioOptions.copyWith(
          receiveTimeout: const Duration(seconds: 10),
          connectTimeout: const Duration(seconds: 10),
        ),
      ),
      baseUrl: Environment.tvCastApiUrl,
    ),
  );
  injector.registerLazySingleton<VersionService>(
    () => VersionServiceImpl(injector(), injector(), injector(), injector()),
  );
  injector.registerLazySingleton<CustomerSupportService>(
    () => CustomerSupportServiceImpl(
      DraftCustomerSupportStore(),
      CustomerSupportApi(
        DioManager().customerSupport(
          dioOptions.copyWith(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ),
        baseUrl: Environment.customerSupportURL,
      ),
      injector(),
    ),
  );
  await injector<CustomerSupportService>().init();

  injector.registerLazySingleton<DomainService>(DomainServiceImpl.new);

  injector.registerLazySingleton<DomainAddressService>(
    () => DomainAddressServiceImpl(injector()),
  );

  injector.registerLazySingleton(
    () => Web3Client(Environment.web3RpcURL, injector()),
  );

  injector.registerLazySingleton<FeralFileApi>(
    () => FeralFileApi(
      DioManager().feralFile(dioOptions),
      baseUrl: Environment.feralFileAPIURL,
    ),
  );
  // injector.registerLazySingleton<IndexerApi>(
  //   () => IndexerApi(dio, baseUrl: Environment.indexerURL),
  // );

  final indexerClient = IndexerClient(
    Environment.indexerURL,
  );
  injector.registerLazySingleton<NftIndexerService>(
    () => NftIndexerService(indexerClient),
  );

  injector.registerLazySingleton<EthereumService>(
    () => EthereumServiceImpl(
      injector(),
      injector(),
    ),
  );

  injector.registerLazySingleton<DeviceInfoService>(DeviceInfoService.new);

  injector.registerLazySingleton<CanvasClientServiceV2>(
    () => CanvasClientServiceV2(injector(), injector()),
  );

  injector.registerLazySingleton<FeralFileService>(
    () => FeralFileServiceImpl(
      injector(),
    ),
  );

  injector.registerLazySingleton<DeeplinkService>(
    () => DeeplinkServiceImpl(
      injector(),
    ),
  );

  injector.registerSingleton<DLSService>(
    DLSServiceImpl(),
  );

  final identityStore = IndexerIdentityStore();
  await identityStore.init();
  injector.registerLazySingleton<IdentityBloc>(
    () => IdentityBloc(identityStore, injector()),
  );

  injector.registerLazySingleton<CanvasDeviceBloc>(
    () => CanvasDeviceBloc(injector()),
  );
  injector.registerLazySingleton<SubscriptionBloc>(
    SubscriptionBloc.new,
  );

  injector.registerLazySingleton<AccountsBloc>(
    () => AccountsBloc(injector(), injector()),
  );

  injector.registerLazySingleton<BluetoothConnectBloc>(
    BluetoothConnectBloc.new,
  );

  injector.registerLazySingleton<AnnouncementStore>(AnnouncementStore.new);
  await injector<AnnouncementStore>().init();

  injector.registerLazySingleton<AnnouncementService>(
    () => AnnouncementServiceImpl(injector(), injector()),
  );

  injector.registerLazySingleton<AppDataManager>(AppDataManager.new);
  await injector<AppDataManager>().init();

  injector.registerLazySingleton<FeedRegistryService>(
    FeedRegistryServiceImpl.new,
  );

  injector.registerLazySingleton<MobileControllerAPI>(
    () => MobileControllerAPI(
      DioManager().mobileController(
        dioOptions.copyWith(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
      baseUrl: Environment.mobileControllerAPIURL,
    ),
  );

  injector.registerLazySingleton<MobileControllerService>(
    () => MobileControllerService(injector()),
  );

  injector.registerLazySingleton<AudioService>(
    AudioService.new,
  );

  // Curated playlists (top 5)
  injector.registerLazySingleton<PlaylistsBloc>(
    () => PlaylistsBloc(
      playlistType: PlaylistType.curated,
      total: null,
    ),
    instanceName: PlaylistsBlocInstance.curated.instanceName,
  );

  // User's playlists (all)
  injector.registerLazySingleton<PlaylistsBloc>(
    () => PlaylistsBloc(
      playlistType: PlaylistType.me,
      total: null,
    ),
    instanceName: PlaylistsBlocInstance.my.instanceName,
  );

  // Global playlists (all)
  injector.registerLazySingleton<PlaylistsBloc>(
    () => PlaylistsBloc(
      playlistType: PlaylistType.global,
      total: null,
    ),
    instanceName: PlaylistsBlocInstance.global.instanceName,
  );

  injector.registerLazySingleton<UserAllOwnCollectionBloc>(
    () => UserAllOwnCollectionBloc(injector()),
  );

  // Curated channels (top 5)
  injector.registerLazySingleton<ChannelsBloc>(
    () => ChannelsBloc(
      channelType: ChannelType.curated,
      total: null,
    ),
    instanceName: ChannelsBlocInstance.curated.instanceName,
  );

  // User's channels (all)
  injector.registerLazySingleton<ChannelsBloc>(
    () => ChannelsBloc(
      channelType: ChannelType.me,
      total: null,
    ),
    instanceName: ChannelsBlocInstance.me.instanceName,
  );

  // Global channels (all)
  injector.registerLazySingleton<ChannelsBloc>(
    () => ChannelsBloc(
      channelType: ChannelType.global,
      total: null,
    ),
    instanceName: ChannelsBlocInstance.global.instanceName,
  );

  injector.registerLazySingleton<DP1FeedApi>(
    () => DP1FeedApi(
      DioManager().dp1Feed(
        dioOptions.copyWith(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ),
      baseUrl: Environment.dp1FeedUrl,
    ),
  );

  injector.registerLazySingleton<WorksBloc>(
    WorksBloc.new,
  );

  final feedManager = FeralFileFeedManager();
  injector.registerSingleton<FeralFileFeedManager>(feedManager);

  injector.registerLazySingleton<FeralFileDP1FeedService>(
    () => FeralFileDP1FeedService(
      baseUrl: Environment.dp1FeedUrl,
    ),
  );

  injector.registerLazySingleton<RecordBloc>(
    () => RecordBloc(
      injector(),
      injector(),
      injector(),
      injector(),
      injector(),
    ),
  );

  // User playlist service (DP1)
  injector.registerLazySingleton<UserDp1PlaylistService>(
    () => UserDp1PlaylistService(),
  );

  // MeiliSearch SDK Service (using official SDK)
  injector.registerLazySingleton<MeiliSearchService>(
    () => MeiliSearchService()..initialize(),
  );

  injector.registerFactory<MeiliSearchBloc>(() => MeiliSearchBloc(injector()));

  injector.registerLazySingleton<SecureStorageServer>(
    SecureStorageServerImpl.new,
  );
}
