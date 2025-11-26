import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/additional_data/additional_data.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_bloc.dart';
import 'package:autonomy_flutter/screen/home/home_state.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/service/client_token_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
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

  Timer? _timer;
  StreamSubscription<FGBGType>? _fgbgSubscription;

  final _announcementService = injector<AnnouncementService>();
  final _remoteConfig = injector<RemoteConfigService>();

  void onHomePageInit(BuildContext context, ObservingState state) {
    final nftBloc = injector<ClientTokenService>().nftBloc;
    final clientTokenService = injector<ClientTokenService>();

    unawaited(injector<CustomerSupportService>().getChatThreads());

    NftCollectionBloc.eventController.stream.listen((event) async {
      switch (event.runtimeType) {
        case const (ReloadEvent):
        case const (GetTokensByOwnerEvent):
        case const (UpdateTokensEvent):
        case const (GetTokensBeforeByOwnerEvent):
          nftBloc.add(event);
        default:
      }
    });
    unawaited(injector<VersionService>().checkForUpdate());
    BluetoothDeviceManager().castingDeviceStatus.addListener(
      () async {
        await Future.delayed(const Duration(milliseconds: 1000));
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
    unawaited(
      clientTokenService.refreshTokens(syncAddresses: true).then(
        (_) {
          nftBloc.add(GetTokensByOwnerEvent(pageKey: PageKey.init()));
        },
      ),
    );

    context.read<HomeBloc>().add(CheckReviewAppEvent());

    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      unawaited(clientTokenService.refreshTokens());
    });

    _triggerShowAnnouncement();

    OneSignal.Notifications.addClickListener((openedResult) async {
      log.info('Tapped push notification: '
          '${openedResult.notification.additionalData}');
      final additionalData =
          AdditionalData.fromJson(openedResult.notification.additionalData!);
      final id = additionalData.announcementContentId ??
          openedResult.notification.notificationId;
      final body = openedResult.notification.body;
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
    _timer?.cancel();
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

    _triggerShowAnnouncement();
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
