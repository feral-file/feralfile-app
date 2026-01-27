import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc_manager.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/network_service.dart';
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
  bool _isShowingOfflineDialog = false;

  final _remoteConfig = injector<RemoteConfigService>();
  final _networkService = injector<NetworkService>();

  void onHomePageInit(BuildContext context, ObservingState state) {
    // Listen to network changes
    _networkService.hasInternetNotifier.addListener(_onNetworkChanged);

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
    _refreshAddressesNeedingReindex();

    unawaited(NowDisplayingManager().updateDisplayingNow());

    context.read<HomeBloc>().add(CheckReviewAppEvent());
    final manager = injector<UserAllOwnCollectionBlocManager>();

    _collectionRefreshTimer?.cancel();
    _collectionRefreshTimer =
        Timer.periodic(const Duration(seconds: 60), (_) async {
      // Skip refresh if app is in background
      if (_isBackground) {
        return;
      }
      try {
        final owners =
            await injector<AddressService>().getAllAddressesFromDrift();
        // filter out addresses that have not been indexed
        final lastFetchTokenTime = injector<UserDp1PlaylistService>()
            .getAddressOldestLastFetchTokenTime(addresses: owners);
        final addressesToRefresh =
            owners.where((e) => lastFetchTokenTime[e] != null).toList();
        log.info('Refreshing tokens for: ${addressesToRefresh}');
        if (addressesToRefresh.isEmpty) {
          log.info('No addresses to refresh');
          return;
        }
        for (final address in addressesToRefresh) {
          final bloc = manager.getBlocForAddresses([address]);
          bloc?.add(UpdateTokens());
        }
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

    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);
  }

  void onHomePageDispose() {
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

  Future<void> _refreshAddressesNeedingReindex() async {
    try {
      final addresses =
          await injector<AddressService>().getAllAddressesFromDrift();

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

      log.info('Addresses to reindex: $addressesToReindex');
      log.info('Addresses to refresh: ${addressesToReindex.toList()}');

      if (addressesToReindex.isNotEmpty) {
        final manager = injector<UserAllOwnCollectionBlocManager>();
        for (final address in addressesToReindex) {
          final bloc = manager.getOrCreateBloc([address]);
          bloc.add(Reindex());
        }
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
  }
}
