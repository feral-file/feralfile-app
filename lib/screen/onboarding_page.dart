//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/metric/dp1_playlist_metric.dart';
import 'package:autonomy_flutter/model/metric/identify_user_payload.dart';
import 'package:autonomy_flutter/onboarding/introduce_page.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/canvas_notification_manager.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/service/dls_service.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/service/metric_service.dart';
import 'package:autonomy_flutter/service/push_notification/notification_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/user_agent_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart';

bool didRunSetup = false;

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin, AfterLayoutMixin<OnboardingPage> {
  final deepLinkService = injector.get<DeeplinkService>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    log.info('OnboardingPage initState');
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _timer = Timer(const Duration(seconds: 10), () {
      log.info('OnboardingPage loading more than 10s');
      unawaited(Sentry.captureMessage('OnboardingPage loading more than 10s'));
    });

    unawaited(_runSetupAndFetchCaches());
  }

  Future<void> _runSetupAndFetchCaches() async {
    try {
      await setup(context);
    } catch (error) {
      log.info('Failed to setup: $error');
      unawaited(Sentry.captureException('Failed to setup: $error'));
      return;
    }

    try {
      await _fetchRuntimeCache();
      log.info('OnboardingPage setup and fetch runtime cache done');
      if (!mounted) {
        return;
      }

      _timer?.cancel();
      if (deepLinkService.isHandlingDeepLink) {
        log.info('Skip navigate home, deeplink is handling');
        return;
      }
      await _goToHomePage(context);
    } catch (error) {
      log.info('Failed to fetch runtime cache: $error');
      unawaited(
        Sentry.captureException(
          'Failed to fetch runtime cache: $error',
        ),
      );
    }
  }

  Future<void> loadRemoteConfigs() async {
    try {
      await injector<RemoteConfigService>().loadConfigs();
      log.info('Remote config loaded');
    } catch (e) {
      log.info('Failed to load remote config: $e');
    }
  }

  Future<void> setup(BuildContext context) async {
    log.info('[OnboardingPage] setup start');
    if (didRunSetup) {
      log.info('Setup already run');
      return;
    }

    Environment.checkAllKeys();
    await DeviceInfo.instance.init();
    await injector<DeviceInfoService>().init();
    await injector<AuthService>().initialize();

    await injector<FFBluetoothService>().init();
    await injector<DLSService>().init();
    await injector<FeralFileFeedManager>().init();
    await injector<FeralFileDP1FeedService>().init();

    await injector<MetricService>().initialize();

    final userId = await injector<AuthService>().getOrGenerateUserId();
    await injector<MetricService>().identifyUser(
      profileId: userId,
      payload: IdentifyUserPayload(
        actorType: ActorType.ffController,
        actorId: userId,
      ),
    );

    // Set version info for user agent
    final packageInfo = await PackageInfo.fromPlatform();
    await injector<ConfigurationService>().setVersionInfo(packageInfo.version);

    await disableLandscapeMode();
    didRunSetup = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    log.info('DefineViewRoutingEvent');
  }

  Future<void> _goToHomePage(BuildContext context) async {
    log.info('[_goToHomePage]');
    final isDoneOnboarding =
        injector<ConfigurationService>().isDoneOnboarding();
    if (isDoneOnboarding) {
      unawaited(
        Navigator.of(context).pushReplacementNamed(AppRouter.homePage),
      );
    } else {
      await Navigator.of(context).pushReplacementNamed(
        AppRouter.onboardingIntroducePage,
        arguments: IntroducePagePayload(
          deeplink: null,
        ),
      );
    }

    // at this point, the user has completed the onboarding
    // so we can registerPushNotifications
    if (injector<AppDataManager>()
        .appSettingsStorageService
        .isNotificationEnabled) {
      await injector<NotificationService>().registerPushNotifications();
    }
    startHandleDeeplinkCompleter.complete();
  }

  Future<void> _fetchRuntimeCache() async {
    log.info('[_fetchRuntimeCache] start');

    // try {
    //   await injector<FeedRegistryService>().ensureUserEcdsaKeypair();
    // } catch (e, s) {
    //   log.info('Failed to ensure user ECDSA keypair: $e');
    //   unawaited(Sentry.captureException(e, stackTrace: s));
    // }

    // Reload Feed caches
    unawaited(
      injector<RemoteConfigService>().loadConfigs().then(
        (_) async {
          final channelUrls = List<String>.from(
            injector<RemoteConfigService>().getConfig<List<dynamic>>(
              ConfigGroup.dp1Playlist,
              ConfigKey.dp1PlaylistChannelUrls,
              <dynamic>[],
            ),
          );
          await injector<FeralFileFeedManager>().setupRemoteConfigChannels(
            channelUrls,
          );
          await injector<FeralFileFeedManager>().reloadAllCache();
        },
        onError: (Object e) {
          log.info('Failed to load remote config: $e');
        },
      ),
    );

    if (!startHandleDeeplinkCompleter.isCompleted) {
      startHandleDeeplinkCompleter.complete();
    }

    log.info('[_fetchRuntimeCache] end');
    if (!mounted) {
      return;
    }
    unawaited(CanvasNotificationManager().start());
  }

  final Widget _onboardingLogo = Semantics(
    label: 'onboarding_logo',
    child: Center(
      child: SvgPicture.asset(
        'assets/images/feral_file_onboarding.svg',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getDarkEmptyAppBar(Colors.transparent),
        backgroundColor: AppColor.primaryBlack,
        body: SafeArea(
          top: false,
          child: Padding(
            padding:
                ResponsiveLayout.pageHorizontalEdgeInsets.copyWith(bottom: 40),
            child: Stack(
              children: [
                _onboardingLogo,
                Positioned.fill(
                  child: Column(
                    children: [
                      const Spacer(),
                      PrimaryButton(
                        text: 'h_loading...'.tr(),
                        isProcessing: true,
                        enabled: false,
                        disabledColor: AppColor.auGreyBackground,
                        textColor: AppColor.white,
                        indicatorColor: AppColor.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
