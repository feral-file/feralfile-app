import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/dp1_playlist_api.dart';
import 'package:autonomy_flutter/gateway/mobile_controller_api.dart';
import 'package:autonomy_flutter/gateway/remote_config_api.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/nft_collection/data/api/indexer_api.dart';
import 'package:autonomy_flutter/nft_collection/database/dao/address_collection_dao.dart';
import 'package:autonomy_flutter/nft_collection/database/dao/dao.dart';
import 'package:autonomy_flutter/nft_collection/database/dao/predefined_collection_dao.dart';
import 'package:autonomy_flutter/nft_collection/database/nft_collection_database.dart';
import 'package:autonomy_flutter/nft_collection/graphql/clients/indexer_client.dart';
import 'package:autonomy_flutter/nft_collection/services/address_service.dart';
import 'package:autonomy_flutter/nft_collection/services/artblocks_service.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/widgets/nft_collection_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/collection_pro/collection_pro_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/home/list_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/bloc/record_controller_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/services/channels_service.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/service/audio_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/client_token_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/dp1_playlist_service.dart';
import 'package:autonomy_flutter/service/ethereum_service.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/mobile_controller_service.dart';
import 'package:autonomy_flutter/service/playlist_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/util/au_file_service.dart';
import 'package:autonomy_flutter/util/dio_manager.dart';
import 'package:autonomy_flutter/widgetbook/mock/dao/mock_address_collection_dao.dart';
import 'package:autonomy_flutter/widgetbook/mock/dao/mock_asset_dao.dart';
import 'package:autonomy_flutter/widgetbook/mock/dao/mock_asset_token_dao.dart';
import 'package:autonomy_flutter/widgetbook/mock/dao/mock_predefine_collection_dao.dart';
import 'package:autonomy_flutter/widgetbook/mock/dao/mock_provenance_dao.dart';
import 'package:autonomy_flutter/widgetbook/mock/dao/mock_token_dao.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_accounts_bloc.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_address_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_announcement_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_audio_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_canvas_client_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_channels_bloc.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_channels_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_client_token_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_cloud_manager.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_configuration_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_customer_support.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_dp1_playlist_api.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_dp1_playlist_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_ethereum_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_feralfile_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_indexer_api.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_indexer_client.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_indexer_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_mobile_controller_api.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_mobile_controller_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_playlist_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_playlists_bloc.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_record_bloc.dart';
import 'package:autonomy_flutter/widgetbook/mock/mock_version_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/nft_collection/mock_nft_address_service.dart';
import 'package:autonomy_flutter/widgetbook/mock/nft_collection/mock_nft_collection_database.dart';
import 'package:autonomy_flutter/widgetbook/mock/nft_collection/mock_token_service.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/data/ff_x1.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockInjector {
  static Future<void> setup() async {
    SharedPreferences.setMockInitialValues({});

    final sharedPreferences = await SharedPreferences.getInstance();

    // Dao

    if (!injector.isRegistered<AssetTokenDao>()) {
      injector.registerLazySingleton<AssetTokenDao>(MockAssetTokenDao.new);
    }

    if (!injector.isRegistered<AssetDao>()) {
      injector.registerLazySingleton<AssetDao>(MockAssetDao.new);
    }

    if (!injector.isRegistered<AddressCollectionDao>()) {
      injector.registerLazySingleton<AddressCollectionDao>(
        MockAddressCollectionDao.new,
      );
    }

    if (!injector.isRegistered<ProvenanceDao>()) {
      injector.registerLazySingleton<ProvenanceDao>(MockProvenanceDao.new);
    }

    if (!injector.isRegistered<TokenDao>()) {
      injector.registerLazySingleton<TokenDao>(MockTokenDao.new);
    }

    // PredefinedCollectionDao
    if (!injector.isRegistered<PredefinedCollectionDao>()) {
      injector.registerLazySingleton<PredefinedCollectionDao>(
        MockPredefinedCollectionDao.new,
      );
    }

    // nft collection database
    if (!injector.isRegistered<NftCollectionDatabase>()) {
      injector.registerLazySingleton<NftCollectionDatabase>(
        MockNftCollectionDatabase.new,
      );
    }

    // NftCollectionPrefs
    if (!injector.isRegistered<NftCollectionPrefs>()) {
      injector.registerLazySingleton<NftCollectionPrefs>(
        () => NftCollectionPrefs(sharedPreferences),
      );
    }

    // Nft address service
    if (!injector.isRegistered<NftAddressService>()) {
      injector
          .registerLazySingleton<NftAddressService>(MockNftAddressService.new);
    }

    // Nft token service
    if (!injector.isRegistered<NftTokensService>()) {
      injector.registerLazySingleton<NftTokensService>(MockTokensService.new);
    }

    if (!injector.isRegistered<AddressService>()) {
      injector.registerLazySingleton<AddressService>(MockAddressService.new);
    }
    if (!injector.isRegistered<CloudManager>()) {
      injector.registerLazySingleton<CloudManager>(MockCloudManager.new);
    }
    if (!injector.isRegistered<CanvasClientServiceV2>()) {
      injector.registerLazySingleton<CanvasClientServiceV2>(
        MockCanvasClientServiceV2.new,
      );
    }

    // ethereum service
    if (!injector.isRegistered<EthereumService>()) {
      injector.registerLazySingleton<EthereumService>(MockEthereumService.new);
    }

    // feralfile service
    if (!injector.isRegistered<FeralFileService>()) {
      injector
          .registerLazySingleton<FeralFileService>(MockFeralfileService.new);
    }

    if (!injector.isRegistered<CanvasDeviceBloc>()) {
      injector.registerLazySingleton<CanvasDeviceBloc>(
        () => CanvasDeviceBloc(injector.get()),
      );
    }

    // artblocks service
    if (!injector.isRegistered<ArtBlockService>()) {
      injector.registerLazySingleton<ArtBlockService>(
        () => ArtBlockService(injector.get()),
      );
    }

    // indexer service
    if (!injector.isRegistered<IndexerClient>()) {
      injector.registerLazySingleton<IndexerClient>(MockIndexerClient.new);
    }
    if (!injector.isRegistered<IndexerApi>()) {
      injector.registerLazySingleton<IndexerApi>(MockIndexerApi.new);
    }
    if (!injector.isRegistered<NftIndexerService>()) {
      injector.registerLazySingleton<NftIndexerService>(
        () =>
            MockIndexerService(injector.get(), injector.get(), injector.get()),
      );
    }

    // token service
    if (!injector.isRegistered<NftTokensService>()) {
      injector.registerLazySingleton<NftTokensService>(MockTokensService.new);
    }

    // ClientTokenService
    if (!injector.isRegistered<ClientTokenService>()) {
      injector.registerLazySingleton<ClientTokenService>(
        MockClientTokenService.new,
      );
    }

    // AnnouncementService
    if (!injector.isRegistered<AnnouncementService>()) {
      injector.registerLazySingleton<AnnouncementService>(
        MockAnnouncementService.new,
      );
    }

    // Customer Support Service
    if (!injector.isRegistered<CustomerSupportService>()) {
      injector.registerLazySingleton<CustomerSupportService>(
        MockCustomerSupportService.new,
      );
    }

    // Version Service
    if (!injector.isRegistered<VersionService>()) {
      injector.registerLazySingleton<VersionService>(
        MockVersionService.new,
      );
    }

    //MockPlaylistService
    if (!injector.isRegistered<PlaylistService>()) {
      injector.registerLazySingleton<PlaylistService>(MockPlaylistService.new);
    }

    // coòniguration service
    if (!injector.isRegistered<ConfigurationService>()) {
      injector.registerLazySingleton<ConfigurationService>(
        () => MockConfigurationService(sharedPreferences),
      );
    }

    if (!injector.isRegistered<RemoteConfigService>()) {
      injector.registerLazySingleton<RemoteConfigService>(
        () => RemoteConfigServiceImpl(
          RemoteConfigApi(DioManager().base(BaseOptions())),
        ),
      );
    }

    // NftCollectionBloc
    if (!injector.isRegistered<NftCollectionBloc>()) {
      injector.registerLazySingleton<NftCollectionBloc>(
        () => NftCollectionBloc(
          injector.get(),
          injector.get(),
          injector.get(),
          injector.get(),
          pendingTokenExpire: const Duration(hours: 4),
        ),
      );
    }

    if (!injector.isRegistered<CacheManager>()) {
      injector.registerLazySingleton<CacheManager>(AUImageCacheManage.new);
    }

    // daily bloc
    if (!injector.isRegistered<DailyWorkBloc>()) {
      injector.registerLazySingleton<DailyWorkBloc>(
        () => DailyWorkBloc(injector.get(), injector.get()),
      );
    }

    // account bloc
    if (!injector.isRegistered<AccountsBloc>()) {
      injector.registerLazySingleton<AccountsBloc>(
        MockAccountsBloc.new,
      );
    }

    // subscription bloc
    if (!injector.isRegistered<SubscriptionBloc>()) {
      injector.registerLazySingleton<SubscriptionBloc>(
        SubscriptionBloc.new,
      );
    }

    //  injector.registerLazySingleton<ListPlaylistBloc>(ListPlaylistBloc.new);
    if (!injector.isRegistered<ListPlaylistBloc>()) {
      injector.registerLazySingleton<ListPlaylistBloc>(
        ListPlaylistBloc.new,
      );
    }

    // Mobile Controller API
    if (!injector.isRegistered<MobileControllerAPI>()) {
      injector.registerLazySingleton<MobileControllerAPI>(
        MockMobileControllerAPI.new,
      );
    }

    // Mobile Controller Service
    if (!injector.isRegistered<MobileControllerService>()) {
      injector.registerLazySingleton<MobileControllerService>(
        () => MockMobileControllerService(injector<MobileControllerAPI>()),
      );
    }

    // Audio Service
    if (!injector.isRegistered<AudioService>()) {
      injector.registerLazySingleton<AudioService>(
        MockAudioService.new,
      );
    }

    // Channels Service
    if (!injector.isRegistered<ChannelsService>()) {
      injector.registerLazySingleton<ChannelsService>(
        () => MockChannelsService(injector<DP1PlaylistApi>(), 'mock-api-key'),
      );
    }

    // DP1PlaylistApi
    if (!injector.isRegistered<DP1PlaylistApi>()) {
      injector.registerLazySingleton<DP1PlaylistApi>(
        MockDP1PlaylistApi.new,
      );
    }

    // Dp1PlaylistService
    if (!injector.isRegistered<Dp1PlaylistService>()) {
      injector.registerLazySingleton<Dp1PlaylistService>(
        () =>
            MockDp1PlaylistService(injector<DP1PlaylistApi>(), 'mock-api-key'),
      );
    }

    // RecordBloc
    if (!injector.isRegistered<RecordBloc>()) {
      injector.registerLazySingleton<RecordBloc>(
        () => MockRecordBloc(
          injector(),
          injector(),
          injector(),
        ),
      );
    }

    // ChannelsBloc
    if (!injector.isRegistered<ChannelsBloc>()) {
      injector.registerFactory<ChannelsBloc>(
        () => MockChannelsBloc(channelsService: injector()),
      );
    }

    // PlaylistsBloc
    if (!injector.isRegistered<PlaylistsBloc>()) {
      injector.registerFactory<PlaylistsBloc>(
        () => MockPlaylistsBloc(playlistService: injector()),
      );
    }

    // Collection Pro Bloc
    if (!injector.isRegistered<CollectionProBloc>()) {
      injector.registerLazySingleton<CollectionProBloc>(
        CollectionProBloc.new,
      );
    }

    final identityStore = IndexerIdentityStore();
    // identity bloc
    if (!injector.isRegistered<IdentityBloc>()) {
      injector.registerLazySingleton<IdentityBloc>(
        () => IdentityBloc(identityStore, injector.get()),
      );
    }
  }

  static T get<T extends Object>() {
    return injector.get<T>();
  }
}

class MockDataSetup {
  static Future<void> setup() async {
    // Initialize the mock injector

    final canvasDevices = MockFFBluetoothDevice.allDevices;
    final mockDeviceAliveMap = <String, bool>{
      for (final device in canvasDevices) device.deviceId: true,
    };

    final mockDeviceInfoMap = <String, DeviceStatus>{
      for (final device in canvasDevices)
        device.deviceId: DeviceStatus(
          screenRotation: ScreenOrientation.portrait,
        ),
    };

    final mockCanvasDeviceStatus = <String, CheckCastingStatusReply>{
      for (final device in canvasDevices)
        device.deviceId: CheckCastingStatusReply(artworks: [], ok: true),
    };

    injector<CanvasDeviceBloc>()
        .state
        .deviceAliveMap
        .addAll(mockDeviceAliveMap);
    injector<CanvasDeviceBloc>().state.deviceInfoMap.addAll(mockDeviceInfoMap);
    injector<CanvasDeviceBloc>()
        .state
        .canvasDeviceStatus
        .addAll(mockCanvasDeviceStatus);
  }
}
