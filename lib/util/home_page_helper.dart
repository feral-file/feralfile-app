import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
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
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/network_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/network_service.dart';
import 'package:autonomy_flutter/service/push_notification/notification_handler.dart';
import 'package:autonomy_flutter/service/push_notification/notification_util.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry/sentry.dart';

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
  bool _isBackground = false;
  bool _hasAddedNotificationListener = false;
  bool _isHomePageInitialized = false;
  bool _isShowingOfflineDialog = false;

  final _announcementService = injector<AnnouncementService>();
  final _remoteConfig = injector<RemoteConfigService>();
  final _networkService = injector<NetworkService>();

  void onHomePageInit(BuildContext context, ObservingState state) {
    _isHomePageInitialized = true;
    // Listen to network changes
    _networkService.hasInternetNotifier.addListener(_onNetworkChanged);

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
      // Skip refresh if app is in background
      if (_isBackground) {
        return;
      }
      try {
        final owners = injector<AddressService>().getAllAddresses();
        // filter out addresses that have not been indexed
        final lastIndexedTime = injector<UserDp1PlaylistService>()
            .getAddressOldestLastIndexTime(addresses: owners);
        final addressesToRefresh =
            owners.where((e) => lastIndexedTime[e] != null).toList();
        log.info('Refreshing tokens for: $addressesToRefresh');
        if (addressesToRefresh.isEmpty) {
          log.info('No addresses to refresh');
          return;
        }
        injector<UserAllOwnCollectionBloc>()
            .add(UpdateTokensOfAddresses(addresses: addressesToRefresh));
      } catch (e) {
        log.info('Error in refresh tokens : $e');
        unawaited(
          Sentry.captureEvent(
            SentryEvent(
              message: SentryMessage('Error in refresh tokens: $e'),
              level: SentryLevel.error,
              throwable: e,
            ),
          ),
        );
        // Silently ignore refresh errors
      }
    });

    _triggerShowAnnouncement();

    // Only add notification listener once to prevent duplicate calls
    if (!_hasAddedNotificationListener) {
      _hasAddedNotificationListener = true;
      if (!OneSignalBootstrap.canUseOneSignal) {
        log.warning('Skipping OneSignal click listener: OneSignal not ready');
      } else {
        OneSignal.Notifications.addClickListener((openedResult) async {
          try {
            log.info('Tapped push notification: '
                '${openedResult.notification.additionalData}');

            // Guard: Only handle notifications when app is properly initialized
            if (!_isHomePageInitialized) {
              log.warning('HomePage not initialized, deferring notification');
              return;
            }

            // Guard: Don't process notifications in background
            if (_isBackground) {
              log.warning('App in background, skipping notification handler');
              return;
            }

            // Guard: Check if notification has additional data
            final rawData = openedResult.notification.additionalData;
            if (rawData == null || rawData.isEmpty) {
              log.warning('Notification has no additional data, skipping');
              return;
            }

            // Guard: Ensure context is still valid before any async operations
            if (!context.mounted) {
              log.warning('Context not mounted when notification clicked');
              return;
            }

            final additionalData = AdditionalData.fromJson(rawData);
            await _announcementService.fetchAnnouncements();

            // Guard: Re-check context after async operation
            if (!context.mounted) {
              log.warning('Context unmounted after fetching announcements');
              return;
            }

            await NotificationHandler.instance
                .handlePushNotificationClicked(context, additionalData);
          } catch (e, stackTrace) {
            log.severe('Error handling notification click: $e', e, stackTrace);
            unawaited(Sentry.captureException(
              e,
              stackTrace: stackTrace,
              hint: Hint.withMap({
                'notification_data': openedResult.notification.additionalData,
              }),
            ));
          }
        });
      }
    }
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);
  }

  void onHomePageDispose() {
    _isHomePageInitialized = false;
    _collectionRefreshTimer?.cancel();
    _fgbgSubscription?.cancel();
    _networkService.hasInternetNotifier.removeListener(_onNetworkChanged);
  }

  void _onNetworkChanged() {
    final hasInternet = _networkService.hasInternetNotifier.value;
    log.info('[HomePageHelper] Network changed - hasInternet: $hasInternet');

    if (!hasInternet && !_isShowingOfflineDialog) {
      // Show offline dialog when connection is lost
      log.info('[HomePageHelper] Connection lost, showing offline dialog');
      _showOfflineDialog();
    } else if (hasInternet && _isShowingOfflineDialog) {
      // Dismiss dialog when connection is restored
      log.info('[HomePageHelper] Connection restored, dismissing dialog');
      _isShowingOfflineDialog = false;
      UIHelper.hideInfoDialog(injector<NavigationService>().context);
    }
  }

  Future<void> _showOfflineDialog() async {
    if (_isShowingOfflineDialog) {
      return;
    }

    _isShowingOfflineDialog = true;
    await UIHelper.showOfflineDialog(
      injector<NavigationService>().context,
      onRetry: () {
        _isShowingOfflineDialog = false;
        // No specific retry action for home page, just dismiss
      },
    );
    _isShowingOfflineDialog = false;
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
    final threshold =
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
      injector<UserAllOwnCollectionBloc>().add(
        FetchTokensOfAddresses(
          addresses: addressesToRefresh,
          shouldUpdateLastRefreshedTime: true,
        ),
      );
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
          injector<NftTokensService>().reindexAddresses(alreadyIndexed),
        );
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
          '[_refreshAddressesNeedingReindex] Reindexing tokens for '
          '${addressesToReindex.toList()}',
        );

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
        _isBackground = false;
        unawaited(_handleForeground());
        memoryValues.isForeground = true;
      case FGBGType.background:
        _isBackground = true;
        memoryValues.isForeground = false;
        // Pause polling timers in tokens service when going to background
        try {
          injector<NftTokensService>().pausePollingTimers();
        } catch (e) {
          log.info('Error pausing polling timers: $e');
        }
    }
  }

  Future<void> _handleForeground() async {
    memoryValues.inForegroundAt = DateTime.now();
    await injector<ConfigurationService>().reload();
    unawaited(injector<VersionService>().checkForUpdate());
    await _remoteConfig.loadConfigs(forceRefresh: true);
    unawaited(NowDisplayingManager().updateDisplayingNow());
    unawaited(injector<FeralFileFeedManager>().reloadAllCache());

    // Resume polling timers in tokens service when coming to foreground
    try {
      injector<NftTokensService>().resumePollingTimers();
    } catch (e) {
      log.info('Error resuming polling timers: $e');
    }

    _triggerShowAnnouncement();
    // refresh stale/missing addresses when app resume
    unawaited(_refreshAddressesNeedingReindex());
  }
}
