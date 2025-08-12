//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: unawaited_futures, type_annotate_public_apis
// ignore_for_file: avoid_annotating_with_dynamic

import 'dart:async';
import 'dart:ui';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/announcement/announcement_adapter.dart';
import 'package:autonomy_flutter/model/draft_customer_support.dart';
import 'package:autonomy_flutter/model/identity.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/au_file_service.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/util/device.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/now_displaying_view.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:floor/floor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

ValueNotifier<bool> shouldShowNowDisplaying = ValueNotifier<bool>(false);
ValueNotifier<bool> shouldShowNowDisplayingOnDisconnect =
    ValueNotifier<bool>(true);
ValueNotifier<bool> nowDisplayingVisibility = ValueNotifier<bool>(true);

void main() async {
  unawaited(
    runZonedGuarded(() async {
      await dotenv.load();
      await SentryFlutter.init(
        (options) {
          options
            ..dsn = Environment.sentryDSN
            ..debug = false
            ..enableAutoSessionTracking = true
            ..tracesSampleRate = 0.25
            ..attachStacktrace = true
            ..beforeSend = (SentryEvent event, Hint hint) {
              // Avoid sending events with "level": "debug"
              if (event.level == SentryLevel.debug) {
                // Return null to drop the event
                return null;
              }
              return event;
            };
        },
        appRunner: () async {
          try {
            await runFeralFileApp();
          } catch (e, stackTrace) {
            await Sentry.captureException(e, stackTrace: stackTrace);
            rethrow;
          }
        },
      );
    }, (Object error, StackTrace stackTrace) async {
      /// Check error is Database issue
      if (error.toString().contains('DatabaseException')) {
        log.info('[DatabaseException] Remove local database and resume app');

        await _deleteLocalDatabase();

        /// Need to setup app again
        Future.delayed(const Duration(milliseconds: 200), () async {
          await _setupApp();
        });
      } else {
        showErrorDialogFromException(error, stackTrace: stackTrace);
      }
    }),
  );
}

Future<void> runFeralFileApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  log.info(
    'Initial Route: ${WidgetsBinding.instance.platformDispatcher.defaultRouteName}',
  );

  // feature/text_localization
  await EasyLocalization.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await FlutterDownloader.initialize();
  await Hive.initFlutter();
  _registerHiveAdapter();

  FlutterDownloader.registerCallback(downloadCallback);
  try {
    await AuFileService().setup();
  } catch (e) {
    log.info('Error in AuFileService setup: $e');
  }

  OneSignal.initialize(Environment.onesignalAppID);
  OneSignal.Debug.setLogLevel(OSLogLevel.error);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColor.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    showErrorDialogFromException(
      details.exception,
      stackTrace: details.stack,
      library: details.library,
    );
  };

  await _setupApp();
}

void _registerHiveAdapter() {
  Hive
    ..registerAdapter(AnnouncementLocalAdapter())
    ..registerAdapter(DraftCustomerSupportAdapter())
    ..registerAdapter(IndexerIdentityAdapter());
}

Future<void> _setupApp() async {
  try {
    await setupLogger();
  } catch (e) {
    log.info('Error in setupLogger: $e');
    Sentry.captureException(e);
  }
  await setupInjector();
  unawaited(injector<DeeplinkService>().setup());
  runApp(
    SDTFScope(
      child: EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('ja')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        useFallbackTranslations: true,
        child: const OverlaySupport.global(
          child: AutonomyApp(),
        ),
      ),
    ),
  );

  Sentry.configureScope((scope) async {
    final deviceID = await getDeviceID();
    scope.setUser(SentryUser(id: deviceID));
  });
}

Future<void> _deleteLocalDatabase() async {
  final appDatabaseMainnet =
      await sqfliteDatabaseFactory.getDatabasePath('app_database_mainnet.db');
  final appDatabaseTestnet =
      await sqfliteDatabaseFactory.getDatabasePath('app_database_testnet.db');
  await sqfliteDatabaseFactory.deleteDatabase(appDatabaseMainnet);
  await sqfliteDatabaseFactory.deleteDatabase(appDatabaseTestnet);
}

class AutonomyApp extends StatelessWidget {
  const AutonomyApp({super.key});

  static double maxWidth = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          maxWidth = constraints.maxWidth;
          return MaterialApp(
            title: 'Autonomy',
            theme: ResponsiveLayout.isMobile
                ? AppTheme.lightTheme()
                : AppTheme.tabletLightTheme(),
            darkTheme: AppTheme.lightTheme(),
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            debugShowCheckedModeBanner: false,
            navigatorKey: injector<NavigationService>().navigatorKey,
            navigatorObservers: [
              routeObserver,
              SentryNavigatorObserver(),
              HeroController(),
            ],
            initialRoute: AppRouter.onboardingPage,
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) => AutonomyAppScaffold(child: child!),
          );
        },
      );
}

class AutonomyAppScaffold extends StatefulWidget {
  const AutonomyAppScaffold({required this.child, super.key});

  final Widget child;

  @override
  State<AutonomyAppScaffold> createState() => _AutonomyAppScaffoldState();
}

class _AutonomyAppScaffoldState extends State<AutonomyAppScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isVisible = true;
  double _lastScrollPosition = 0;

  // 40: padding bottom of app bar
  // 45: height of app bar
  // 10: space between app bar and now displaying
  static const double kStatusBarMarginBottom = 40 + 45 + 10;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0,
    );

    shouldShowNowDisplaying.addListener(_updateAnimationBasedOnDisplayState);
    shouldShowNowDisplayingOnDisconnect
        .addListener(_updateAnimationBasedOnDisplayState);
    nowDisplayingVisibility.addListener(_updateAnimationBasedOnDisplayState);
  }

  void _updateAnimationBasedOnDisplayState() {
    final shouldShow = shouldShowNowDisplaying.value &&
        shouldShowNowDisplayingOnDisconnect.value &&
        nowDisplayingVisibility.value;
    final isBetaTester = injector<AuthService>().isBetaTester();
    if (shouldShow && isBetaTester) {
      _animationController.forward();
      setState(() => _isVisible = true);
    } else {
      _animationController.reverse();
      setState(() => _isVisible = false);
    }
  }

  void _handleScrollUpdate(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return;
    }
    if (notification is ScrollUpdateNotification) {
      final currentScroll = notification.metrics.pixels;
      final scrollDelta = currentScroll - _lastScrollPosition;

      if (scrollDelta > 10 && _isVisible) {
        nowDisplayingVisibility.value = false;
        setState(() => _isVisible = false);
      } else if (scrollDelta < -10 && !_isVisible) {
        nowDisplayingVisibility.value = true;
        setState(() => _isVisible = true);
      }

      _lastScrollPosition = currentScroll;
    }
    return;
  }

  @override
  void dispose() {
    shouldShowNowDisplaying.removeListener(_updateAnimationBasedOnDisplayState);
    shouldShowNowDisplayingOnDisconnect
        .removeListener(_updateAnimationBasedOnDisplayState);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScrollUpdate(notification);
          return false; // Allow the notification to continue to be dispatched
        },
        child: Stack(
          children: [
            widget.child,
            ValueListenableBuilder(
              valueListenable: CustomRouteObserver.bottomSheetHeight,
              builder: (context, bottomSheetHeight, child) {
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 150),
                  bottom: bottomSheetHeight > 0
                      ? 10 + bottomSheetHeight
                      : kStatusBarMarginBottom,
                  left: 10,
                  right: 10,
                  child: FadeTransition(
                    opacity: _animationController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(
                          0,
                          kStatusBarMarginBottom / kNowDisplayingHeight,
                        ),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: IgnorePointer(
                        ignoring: !_isVisible,
                        child: NowDisplaying(
                          key: GlobalKey(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final RouteObserver<ModalRoute<void>> routeObserver =
    CustomRouteObserver<ModalRoute<void>>();

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}
