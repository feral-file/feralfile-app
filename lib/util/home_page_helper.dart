import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/additional_data/additional_data.dart';
import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/notifications/notification_handler.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class ObservingState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  // init
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  // dispose
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HomePageHelper {
  // singleton
  HomePageHelper._();

  static final HomePageHelper instance = HomePageHelper._();

  Timer? _collectionRefreshTimer;
  StreamSubscription<FGBGType>? _fgbgSubscription;

  final _announcementService = injector<AnnouncementService>();
  final _remoteConfig = injector<RemoteConfigService>();

  void onHomePageInit(BuildContext context, ObservingState state) {
    unawaited(injector<CustomerSupportService>().getChatThreads());

    // check for version compatibility
    unawaited(injector<VersionService>().checkForUpdate());
    BluetoothDeviceManager().castingDeviceStatus.addListener(
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        final castingDevice = BluetoothDeviceManager().castingBluetoothDevice;
        final isAlive = castingDevice != null &&
            injector<CanvasDeviceBloc>().state.isDeviceAlive(castingDevice);
        if (isAlive) {
          log.info('Casting device is alive: ${castingDevice.name}');
          final compatibility = await injector<VersionService>()
              .checkDeviceVersionCompatibility();
          log.info('Compatibility check result: $compatibility');
        } else {
          log.info('Casting device is not alive or not set');
        }
      },
    );
    unawaited(_forceFetchTokensOfAddresses());
    _refreshAddressesNeedingReindex();

    unawaited(NowDisplayingManager().updateDisplayingNow());

    context.read<HomeBloc>().add(CheckReviewAppEvent());

    _collectionRefreshTimer?.cancel();
    _collectionRefreshTimer =
        Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final allOwnedPlaylist =
            injector<UserDp1PlaylistService>().cachedAllOwnedPlaylist;
        final dynamicQuery = allOwnedPlaylist.firstDynamicQuery;
        if (dynamicQuery != null) {
          final owners = dynamicQuery.params.owners;
          // filter out addresses that have not been indexed
          final lastIndexedTime = injector<UserDp1PlaylistService>()
              .getAddressOldestLastIndexTime(addresses: owners);
          final addressesToRefresh =
              owners.where((e) => lastIndexedTime[e] != null).toList();
          log.info('Refreshing tokens for ${addressesToRefresh}');
          injector<UserAllOwnCollectionBloc>()
              .add(UpdateTokensOfAddresses(addresses: addressesToRefresh));
        } else {
          log.info('No dynamic query found');
        }
      } catch (e) {
        log.info('Error in refresh tokens : $e');
        // Silently ignore refresh errors
      }
    });

    _triggerShowAnnouncement();

    OneSignal.Notifications.addClickListener((openedResult) async {
      log.info('Tapped push notification: '
          '${openedResult.notification.additionalData}');
      final additionalData =
          AdditionalData.fromJson(openedResult.notification.additionalData!);
      await _announcementService.fetchAnnouncements();
      if (!context.mounted) {
        return;
      }
      unawaited(
        NotificationHandler.instance
            .handlePushNotificationClicked(context, additionalData),
      );
    });
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);
  }

  void onHomePageDispose() {
    _collectionRefreshTimer?.cancel();
    _fgbgSubscription?.cancel();
  }

  void _triggerShowAnnouncement() {
    unawaited(
      Future.delayed(const Duration(milliseconds: 2000), () {
        _announcementService.fetchAnnouncements().then(
          (_) async {
            await _announcementService.showOldestAnnouncement();
          },
        );
      }),
    );
  }

  Future<void> _forceFetchTokensOfAddresses() async {
    final addresses = injector<AddressService>().getAllAddresses();
    final refreshedMap = injector<UserDp1PlaylistService>()
        .getAddressOldestLastFetchTokenTime(addresses: addresses);

    final rc = injector<RemoteConfigService>();
    if (!rc.isLoaded) {
      await rc.loadConfigs();
    }

    // Read cache policy (cache_valid_duration can be null/missing)
    final cacheValidStr = rc.getConfig<String?>(
      ConfigGroup.tokenMetadataRebuild,
      ConfigKey.cacheValidDuration,
      null,
    );
    final int? cacheValidSeconds =
        cacheValidStr != null ? int.tryParse(cacheValidStr) : null;
    final lastForceUpdateIso = rc.getConfig<String>(
      ConfigGroup.tokenMetadataRebuild,
      ConfigKey.lastForceUpdateTime,
      '2025-01-01T00:00:00Z',
    );

    final now = DateTime.now().toUtc();
    final Duration? threshold =
        cacheValidSeconds != null ? Duration(seconds: cacheValidSeconds) : null;
    final lastForceUpdateTime = DateTime.tryParse(lastForceUpdateIso)?.toUtc();

    final addressesToRefresh = <String>[];
    for (final addr in addresses) {
      final isFetched =
          injector<UserDp1PlaylistService>().isAddressFetched(addr);
      final isIndexed =
          injector<UserDp1PlaylistService>().isAddressIndexed(addr);
      final last = refreshedMap[addr]?.toUtc();
      final isExpired =
          threshold != null && last != null && now.difference(last) > threshold;
      final isBeforeForced = lastForceUpdateTime != null &&
          (last == null || last.isBefore(lastForceUpdateTime));
      if ((!isFetched && isIndexed) || isExpired || isBeforeForced) {
        addressesToRefresh.add(addr);
      }
    }

    if (addressesToRefresh.isNotEmpty) {
      log.info('Force fetching tokens for ${addressesToRefresh.toList()}');
      injector<UserAllOwnCollectionBloc>().add(FetchTokensOfAddresses(
          addresses: addressesToRefresh, shouldUpdateLastRefreshedTime: true));
    }
  }

  Future<void> _refreshAddressesNeedingReindex() async {
    try {
      final addresses = injector<AddressService>().getAllAddresses();

      final addressesToReindex = <String>[];
      for (final addr in addresses) {
        final isIndexed =
            injector<UserDp1PlaylistService>().isAddressIndexed(addr);

        if (!isIndexed) {
          addressesToReindex.add(addr);
        }
      }

      final alreadyIndexed = addresses
          .where((addr) => !addressesToReindex.contains(addr))
          .toList();

      NftCollection.logger.info('Already indexed addresses: $alreadyIndexed');
      if (alreadyIndexed.isNotEmpty) {
        unawaited(
            injector<NftTokensService>().reindexAddresses(alreadyIndexed));
      }

      log.info('Addresses to reindex: $addressesToReindex');
      log.info('Addresses to refresh: ${addressesToReindex.toList()}');

      if (addressesToReindex.isNotEmpty) {
        log.info('Clearing cached tokens for ${addressesToReindex.toList()}');

        // Clear cached tokens for these addresses before fetching
        final db = injector<IndexerDatabaseAbstract>();
        final tokens =
            db.getTokensByOwners(owners: addressesToReindex.toList());
        if (tokens.isNotEmpty) {
          final cids = tokens.map((v2.AssetToken t) => t.cid).toList();
          db.deleteTokens(cids);
        }

        log.info(
            '[_refreshAddressesNeedingReindex] Reindexing tokens for ${addressesToReindex.toList()}');

        injector<UserAllOwnCollectionBloc>()
            .add(ReindexAddresses(addresses: addressesToReindex.toList()));
      }
    } catch (_) {
      // ignore errors in background refresh
    }
  }

  Future<void> _handleForeBackground(FGBGType event) async {
    switch (event) {
      case FGBGType.foreground:
        unawaited(_handleForeground());
        memoryValues.isForeground = true;
      case FGBGType.background:
        memoryValues.isForeground = false;
        _handleBackground();
    }
  }

  Future<void> _handleForeground() async {
    memoryValues.inForegroundAt = DateTime.now();
    await injector<ConfigurationService>().reload();
    await injector<CloudManager>().downloadAll(includePlaylists: true);
    unawaited(injector<VersionService>().checkForUpdate());
    await _remoteConfig.loadConfigs(forceRefresh: true);
    unawaited(NowDisplayingManager().updateDisplayingNow());
    unawaited(injector<FeralFileFeedManager>().reloadAllCache());

    _triggerShowAnnouncement();
    // refresh stale/missing addresses when app resume
    unawaited(_refreshAddressesNeedingReindex());
  }

  void _handleBackground() {
    unawaited(_checkForReferralCode());
  }

  Future<void> _checkForReferralCode() async {
    final referralCode = injector<ConfigurationService>().getReferralCode();
    if (referralCode != null && referralCode.isNotEmpty) {
      await injector<DeeplinkService>().handleReferralCode(referralCode);
    }
  }
}
