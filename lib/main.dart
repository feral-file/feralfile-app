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
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/model/announcement/announcement_adapter.dart';
import 'package:autonomy_flutter/model/draft_customer_support.dart';
import 'package:autonomy_flutter/model/identity.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/app_theme.dart';
import 'package:autonomy_flutter/util/au_file_service.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/util/device.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/llm_text_input.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:floor/floor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:system_date_time_format/system_date_time_format.dart';

// This value notifies which screen should be shown
ValueNotifier<bool> shouldShowNowDisplaying = ValueNotifier<bool>(false);

// This value notifies if user did tap on close icon to hide now displaying
ValueNotifier<bool> shouldShowNowDisplayingOnDisconnect =
    ValueNotifier<bool>(true);

// This value notifies if now displaying is visible on scroll
ValueNotifier<bool> nowDisplayingVisibility = ValueNotifier<bool>(true);

// This value indicates whether the display is currently active. Its value is a combination of the three values above.
ValueNotifier<bool> nowDisplayingShowing = ValueNotifier<bool>(false);

final keyboardVisibilityController = KeyboardVisibilityController();
final ValueNotifier<bool> shouldHideKeyboardOnTap = ValueNotifier<bool>(
    true); // This value notifies if keyboard should be hidden on tap

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
      systemNavigationBarColor: AppColor.auGreyBackground,
      systemNavigationBarIconBrightness: Brightness.light,
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
  late final ValueNotifier<bool> _shouldShowOverlay;

  StreamSubscription<bool>? _keyboardVisibilitySubscription;
  StreamSubscription<NowDisplayingStatus?>? _nowDisplayingStreamSubscription;

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
    CustomRouteObserver.bottomSheetHeight
        .addListener(_updateAnimationBasedOnDisplayState);
    _nowDisplayingStreamSubscription =
        NowDisplayingManager().nowDisplayingStream.listen((_) {
      _updateAnimationBasedOnDisplayState();
    });

    _keyboardVisibilitySubscription =
        keyboardVisibilityController.onChange.listen((_) {
      _updateAnimationBasedOnDisplayState();
    });

    _shouldShowOverlay = ValueNotifier(false);
    _updateOverlayVisibility();
    isNowDisplayingBarExpanded.addListener(_updateOverlayVisibility);
    nowDisplayingShowing.addListener(_updateOverlayVisibility);
  }

  void _updateAnimationBasedOnDisplayState() {
    final shouldShow = shouldShowNowDisplaying.value &&
        shouldShowNowDisplayingOnDisconnect.value &&
        nowDisplayingVisibility.value &&
        CustomRouteObserver.bottomSheetHeight.value == 0 &&
        !keyboardVisibilityController.isVisible;
    nowDisplayingShowing.value = shouldShow;
    if (nowDisplayingShowing.value) {
      _animationController.forward();
      setState(() => _isVisible = true);
    } else {
      _animationController.reverse();
      setState(() => _isVisible = false);
    }
  }

  void _updateOverlayVisibility() {
    _shouldShowOverlay.value =
        isNowDisplayingBarExpanded.value && nowDisplayingShowing.value;
  }

  @override
  void dispose() {
    shouldShowNowDisplaying.removeListener(_updateAnimationBasedOnDisplayState);
    shouldShowNowDisplayingOnDisconnect
        .removeListener(_updateAnimationBasedOnDisplayState);
    nowDisplayingVisibility.removeListener(_updateAnimationBasedOnDisplayState);
    CustomRouteObserver.bottomSheetHeight
        .removeListener(_updateAnimationBasedOnDisplayState);
    isNowDisplayingBarExpanded.removeListener(_updateOverlayVisibility);
    nowDisplayingShowing.removeListener(_updateOverlayVisibility);

    _shouldShowOverlay.dispose();
    _nowDisplayingStreamSubscription?.cancel();
    _animationController.dispose();
    _keyboardVisibilitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // _handleScrollUpdate(notification);
          return false; // Allow the notification to continue to be dispatched
        },
        child: Listener(
          onPointerDown: keyboardVisibilityController.isVisible &&
                  shouldHideKeyboardOnTap.value
              ? (PointerDownEvent event) {
                  // Hide keyboard when tapping outside while keyboard is visible
                  Timer(const Duration(milliseconds: 100), () {
                    log.info('Hiding keyboard');
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                    FocusScope.of(context).unfocus();
                    log.info('Keyboard hidden');
                  });
                }
              : null,
          child: Stack(
            children: [
              widget.child,
              ValueListenableBuilder<bool>(
                valueListenable: _shouldShowOverlay,
                builder: (context, shouldShowOverlay, child) {
                  return shouldShowOverlay
                      ? Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (_isVisible) {
                                DraggableSheetController.collapseSheet();
                              }
                            },
                            child: AnimatedContainer(
                              color: AppColor.primaryBlack.withAlpha(51),
                              duration: const Duration(milliseconds: 150),
                            ), // Transparent area
                          ),
                        )
                      : const SizedBox();
                },
              ),
              Visibility(
                visible: _isVisible,
                child: ValueListenableBuilder(
                  valueListenable: isNowDisplayingBarExpanded,
                  builder: (context, bottomSheetHeight, child) {
                    final paddingBottom = MediaQuery.of(context).padding.bottom;
                    return Positioned(
                      bottom: paddingBottom +
                          UIConstants.nowDisplayingBarBottomPadding +
                          NowPlayingBarTokens.collapseHeight,
                      left: 0,
                      right: 0,
                      child: const LLMTextInput(),
                    );
                  },
                ),
              ),
              Visibility(
                visible: _isVisible,
                replacement: const SizedBox.shrink(),
                child: ValueListenableBuilder(
                  valueListenable: CustomRouteObserver.bottomSheetHeight,
                  builder: (context, bottomSheetHeight, child) {
                    final paddingBottom = MediaQuery.of(context).padding.bottom;
                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 150),
                      bottom: bottomSheetHeight > 0
                          ? bottomSheetHeight +
                              paddingBottom +
                              UIConstants.nowDisplayingBarBottomPadding
                          : paddingBottom +
                              UIConstants.nowDisplayingBarBottomPadding,
                      left: ResponsiveLayout.paddingHorizontal,
                      right: ResponsiveLayout.paddingHorizontal,
                      child: FadeTransition(
                        opacity: _animationController,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(
                              0,
                              paddingBottom / kNowDisplayingHeight,
                            ),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _animationController,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: const NowDisplayingBar(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final CustomRouteObserver<ModalRoute<void>> routeObserver =
    CustomRouteObserver<ModalRoute<void>>();

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}
