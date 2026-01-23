import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/hive_database.dart';
import 'package:autonomy_flutter/database/hive_storage_service.dart';
import 'package:autonomy_flutter/service/app_data/address_storage_service.dart';
import 'package:autonomy_flutter/service/app_data/dp1_feed_storage_service.dart';
import 'package:autonomy_flutter/service/app_data/playlist_storage_service.dart';
import 'package:autonomy_flutter/service/app_data/settings_storage_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppDataManager {
  AppDataManager();

  Future<void> init() async {
    await _init();
  }

  late final String _flavor;

  // Storages services
  late final AddressStorageService _addressStorageService;
  late final DP1FeedStorageService _dp1FeedStorageService;
  late final PlaylistStorageService _playlistStorageService;
  late final SettingsStorageService _appSettingsStorageService;
  late final StorageService _ffDeviceStorageService;

  Future<void> _getFlavor() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _flavor = packageInfo.packageName.contains('inhouse')
        ? 'mobile_inhouse'
        : 'mobile_prd';
  }

  Future<void> _init() async {
    await _getFlavor();

    // Initialize Hive database (simple key-value storage)
    final hiveDB = injector<HiveDatabase>();
    await hiveDB.init();

    // --- 1. Wallet Address ---
    final addressPrefix =
        [_flavor, _commonKeyPrefix, _db, _addressKeyPrefix].join('.');
    _addressStorageService = AddressStorageService(hiveDB, addressPrefix);

    // --- 2. App Settings ---
    final appSettingsPrefix =
        [_flavor, _commonKeyPrefix, _db, _settingsKeyPrefix].join('.');
    _appSettingsStorageService = SettingsStorageService(
      hiveDB,
      appSettingsPrefix,
    );

    // --- 3. Playlist ---
    final playlistPrefix =
        [_flavor, _commonKeyPrefix, _db, _playlistKeyPrefix].join('.');
    _playlistStorageService = PlaylistStorageService(hiveDB, playlistPrefix);

    // --- 4. DP1 Feed ---
    final dp1Prefix =
        [_flavor, _commonKeyPrefix, _db, _dp1FeedKeyPrefix].join('.');
    _dp1FeedStorageService = DP1FeedStorageService(hiveDB, dp1Prefix);

    // --- 5. FF Device ---
    final ffDevicePrefix =
        [_flavor, _commonKeyPrefix, _db, _ffDeviceKeyPrefix].join('.');
    _ffDeviceStorageService = HiveStorageService(hiveDB, ffDevicePrefix);

    log.info('[SettingsManager] Initialized with Hive database');
  }

  static const _commonKeyPrefix = 'common';
  static const _db = 'db';
  static const _settingsKeyPrefix = 'settings';
  static const _addressKeyPrefix = 'address';
  static const _playlistKeyPrefix = 'playlist';
  static const _dp1FeedKeyPrefix = 'dp1_feed';
  static const _ffDeviceKeyPrefix = 'ff_device';

  AddressStorageService get addressStorageService => _addressStorageService;
  DP1FeedStorageService get dp1FeedStorageService => _dp1FeedStorageService;
  PlaylistStorageService get playlistStorageService => _playlistStorageService;
  SettingsStorageService get appSettingsStorageService =>
      _appSettingsStorageService;
  StorageService get ffDeviceStorageService => _ffDeviceStorageService;

  Future<void> deleteAll() async {
    await _appSettingsStorageService.deleteAll();
    await _addressStorageService.deleteAll();
    await _playlistStorageService.deleteAll();
    await _dp1FeedStorageService.deleteAll();
    await _ffDeviceStorageService.deleteAll();

    log.info('[AppDataManager] Local app data deleted');
  }
}
