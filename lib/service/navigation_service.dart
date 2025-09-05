//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/model/jwt.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/database/nft_collection_database.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/alumni_details/alumni_details_page.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/github_doc.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/feral_file_custom_tab.dart';
import 'package:autonomy_flutter/util/feral_file_helper.dart';
import 'package:autonomy_flutter/util/gesture_constrain_widget.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artist_display_setting.dart';
import 'package:autonomy_flutter/view/how_to_install_daily_widget_build.dart';
import 'package:autonomy_flutter/view/now_display_setting.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/stream_device_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:open_settings_plus/open_settings_plus.dart';
import 'package:sentry/sentry.dart';
import 'package:url_launcher/url_launcher_string.dart';

class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  PageController? _pageController;

  static const Key contactingKey = Key('tezos_beacon_contacting');

  // to prevent showing duplicate ConnectPage
  // workaround solution for unknown reason
  // ModalRoute(navigatorKey.currentContext) returns nil
  final _browser = FeralFileBrowser();

  PageController? get pageController => _pageController;

  void setGlobalHomeTabController(PageController? controller) {
    _pageController = controller;
  }

  BuildContext get context => navigatorKey.currentContext!;

  bool get mounted => navigatorKey.currentContext?.mounted == true;

  // current route
  Route<dynamic>? get currentRoute => CustomRouteObserver.currentRoute.value;

  Future<dynamic>? navigateTo(String routeName, {Object? arguments}) {
    log.info('NavigationService.navigateTo: $routeName');
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return null;
    }

    return navigatorKey.currentState
        ?.pushNamed(routeName, arguments: arguments);
  }

  Future<dynamic>? popAndPushNamed(String routeName, {Object? arguments}) {
    log.info('NavigationService.popAndPushNamed: $routeName');
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return null;
    }

    return navigatorKey.currentState
        ?.popAndPushNamed(routeName, arguments: arguments);
  }

  Future<dynamic>? navigateUntil(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) {
    log.info('NavigationService.navigateTo: $routeName');

    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return null;
    }

    return navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(routeName, predicate);
  }

  NavigatorState navigatorState() => Navigator.of(navigatorKey.currentContext!);

  void showErrorDialog(
    ErrorEvent event, {
    FutureOr<void> Function()? defaultAction,
    FutureOr<void> Function()? cancelAction,
  }) {
    log.info('NavigationService.showErrorDialog');

    if (navigatorKey.currentState?.mounted == true &&
        navigatorKey.currentContext != null) {
      showEventErrorDialog(
        navigatorKey.currentContext!,
        event,
        defaultAction: defaultAction,
        cancelAction: cancelAction,
      );
    }
  }

  void hideInfoDialog() {
    if (navigatorKey.currentState?.mounted == true &&
        navigatorKey.currentContext != null) {
      UIHelper.hideInfoDialog(navigatorKey.currentContext!);
    }
  }

  Future<void> openAuthenticationSettings() async {
    if (Platform.isAndroid) {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusAndroid;
      await settings.biometricEnroll();
    } else {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusIOS;
      await settings.faceIDAndPasscode();
    }
  }

  Future<void> openBluetoothSettings() async {
    if (Platform.isAndroid) {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusAndroid;
      // can not go to bluetooth settings, so we go to application settings
      // from here, user can go to bluetooth settings
      await settings.applicationDetails();
    } else {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusIOS;
      await settings.appSettings();
    }
  }

  Future<void> openMicrophoneSettings() async {
    if (Platform.isAndroid) {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusAndroid;
      await settings.applicationDetails();
    } else {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusIOS;
      await settings.appSettings();
    }
  }

  Future<void> openDeviceSettings() async {
    if (Platform.isAndroid) {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusAndroid;
      await settings.apnSettings();
    } else {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusIOS;
      await settings.appSettings();
    }
  }

  Future<void> openAccountSettings() async {
    if (Platform.isAndroid) {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusAndroid;
      await settings.apnSettings();
    } else {
      final settings = OpenSettingsPlus.shared! as OpenSettingsPlusIOS;
      await settings.appSettings();
    }
  }

  Future<void> showAppLoadError() async {
    if (navigatorKey.currentState?.mounted == true &&
        navigatorKey.currentContext != null) {
      if (isShowErrorDialogWorking != null) {
        // pop the error dialog if it is showing
        isShowErrorDialogWorking = null;
        UIHelper.hideInfoDialog(navigatorKey.currentContext!);
      }
      isShowErrorDialogWorking = DateTime.now();
      final theme = Theme.of(context);
      unawaited(Sentry.captureMessage('App Load Error'));
      await UIHelper.showDialog(
        context,
        'App Load Error',
        Column(
          children: [
            SelectableText(
              'it_seem_loading_issue'.tr(),
              style: theme.textTheme.ppMori400White14,
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: theme.textTheme.ppMori400White14,
                children: <TextSpan>[
                  TextSpan(
                    text: '${'if_issue_persist'.tr()} ',
                  ),
                  TextSpan(
                    text: 'feralfile@support.com'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        log.info('send email to feralfile@support.com');
                        const href = 'mailto:support@feralfile.com';
                        launchUrlString(href);
                      },
                  ),
                  TextSpan(
                    text: ' ${'for_assistance'.tr()}',
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      await Future.delayed(const Duration(seconds: 1), () {
        isShowErrorDialogWorking = null;
      });
    }
  }

  void goBack({Object? result}) {
    log.info('NavigationService.goBack');
    return navigatorKey.currentState?.pop(result);
  }

  void popUntilHome() {
    navigatorKey.currentState?.popUntil(
      (route) =>
          route.settings.name == AppRouter.homePage ||
          route.settings.name == AppRouter.homePage,
    );
  }

  void popUntil(String route) {
    navigatorKey.currentState?.popUntil(
      (r) => r.settings.name == route,
    );
  }

  void popUntilHomeOrSettings() {
    navigatorKey.currentState?.popUntil(
      (route) =>
          route.settings.name == AppRouter.settingsPage ||
          route.settings.name == AppRouter.homePage ||
          route.settings.name == AppRouter.homePage,
    );
  }

  /// Pop to a specific route if it exists in the stack, otherwise push a new route
  ///
  /// [routeName] - The route name to navigate to
  /// [arguments] - Optional arguments for the route
  /// [pushIfNotExists] - Whether to push the route if it doesn't exist in stack (default: true)
  ///
  /// Returns true if popped to existing route, false if pushed new route
  Future<bool> popToRouteOrPush(String routeName, {Object? arguments}) async {
    log.info('NavigationService.popToRouteOrPush: $routeName');

    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return false;
    }

    // Check if the route exists in the current stack
    final isRouteInStack = CustomRouteObserver.isRouteInStack(routeName);

    if (isRouteInStack) {
      // Route exists in stack, pop to it
      log.info('Route $routeName found in stack, popping to it');
      navigatorKey.currentState?.popUntil(
        (route) => route.settings.name == routeName,
      );
      return true;
    } else {
      // Route doesn't exist in stack, push new route
      log.info('Route $routeName not found in stack, pushing new route');
      await navigatorKey.currentState
          ?.pushNamed(routeName, arguments: arguments);
      return false;
    }
  }

  Future<void> waitTooLongDialog() async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        navigatorKey.currentContext!,
        'taking_too_long'.tr(),
        'if_take_too_long'.tr(),
        closeButton: 'cancel'.tr(),
        autoDismissAfter: 20,
        onClose: hideInfoDialog,
      );
    }
  }

  Future<void> showCannotConnectTv() async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        context,
        'can_not_connect_to_tv'.tr(),
        'can_not_connect_to_tv_desc'.tr(),
        onClose: () => UIHelper.hideInfoDialog(context),
      );
    }
  }

  Future<void> showCannotConnectToBluetoothDevice(
    BluetoothDevice device,
    Object? error,
  ) async {
    hideInfoDialog();
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        context,
        'Can not connect to ${device.getName}',
        'Error: ${error}',
        onClose: () => UIHelper.hideInfoDialog(context),
      );
    }
  }

  Future<void> showUnknownLink() async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        context,
        'unknown_link'.tr(),
        'unknown_link_desc'.tr(),
        onClose: () => UIHelper.hideInfoDialog(context),
      );
    }
  }

  Future<void> gotoExhibitionDetailsPage(String exhibitionID) async {
    popUntilHome();
    await Future.delayed(const Duration(seconds: 1), () async {
      await (homePageKey.currentState ?? homePageNoTransactionKey.currentState)
          ?.openExhibition(exhibitionID);
    });
  }

  Future<void> popToCollection() async {
    popUntilHome();
    await injector<NavigationService>().openCollection();
  }

  Future<void> gotoArtworkDetailsPage(String indexID) async {
    popUntilHome();
    final tokens = await injector<NftCollectionDatabase>()
        .assetTokenDao
        .findAllAssetTokensByTokenIDs([indexID]);
    final owner = tokens.first.owner;
    final artworkDetailPayload =
        ArtworkDetailPayload(ArtworkIdentity(indexID, owner));
    if (context.mounted) {
      unawaited(
        Navigator.of(context).pushNamed(
          AppRouter.artworkDetailsPage,
          arguments: artworkDetailPayload,
        ),
      );
    }
  }

  Future<void> openAutonomyDocument(String href, String title) async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      final uri = Uri.parse(href.autonomyRawDocumentLink);
      final document = uri.pathSegments.last;
      final prefix =
          uri.pathSegments.sublist(0, uri.pathSegments.length - 1).join('/');
      await Navigator.of(navigatorKey.currentContext!).pushNamed(
        AppRouter.githubDocPage,
        arguments: GithubDocPayload(
          title: title,
          prefix: '/$prefix',
          document: '/$document',
        ),
      );
    }
  }

  Future<void> openFeralFileArtistPage(String id) async {
    if (id.contains(',') || id.isEmpty) {
      return;
    }
    await Navigator.of(navigatorKey.currentContext!).pushNamed(
      AppRouter.alumniDetailsPage,
      arguments: AlumniDetailsPagePayload(alumniID: id),
    );
  }

  Future<void> openFeralFileCuratorPage(String id) async {
    if (id.contains(',') || id.isEmpty) {
      return;
    }
    await Navigator.of(navigatorKey.currentContext!).pushNamed(
      AppRouter.alumniDetailsPage,
      arguments: AlumniDetailsPagePayload(alumniID: id),
    );
  }

  Future<void> openFeralFileExhibitionNotePage(String exhibitionSlug) async {
    if (exhibitionSlug.isEmpty) {
      return;
    }
    final url = FeralFileHelper.getExhibitionNoteUrl(exhibitionSlug);
    await _browser.openUrl(url);
  }

  Future<void> openCollection() async {
    await navigateTo(AppRouter.collectionPage);
  }

  Future<void> openFeralFilePostPage(Post post, String exhibitionID) async {
    if (post.slug.isEmpty || exhibitionID.isEmpty) {
      return;
    }
    final url = FeralFileHelper.getPostUrl(post, exhibitionID);
    await _browser.openUrl(url);
  }

  Future<void> navigatePath(String? path) async {
    final pair = _resolvePath(path);
    if (pair == null) {
      return;
    }
    late String route;
    HomeNavigatorTab? homeNavigationTab;
    FeralfileHomeTab? exploreTab;

    switch (pair.first) {
      case AppRouter.dailyWorkPage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.daily;
      case AppRouter.featuredPage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.explore;
        exploreTab = FeralfileHomeTab.featured;
      case AppRouter.artworksPage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.explore;
        exploreTab = FeralfileHomeTab.artworks;
      case AppRouter.exhibitionsPage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.explore;
        exploreTab = FeralfileHomeTab.exhibitions;
      case AppRouter.artistsPage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.explore;
        exploreTab = FeralfileHomeTab.artists;
      case AppRouter.curatorsPage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.explore;
        exploreTab = FeralfileHomeTab.curators;
      case AppRouter.organizePage:
        route = AppRouter.homePage;
        homeNavigationTab = HomeNavigatorTab.collection;
      default:
        route = pair.first;
        unawaited(navigateTo(route, arguments: pair.second));
        return;
    }

    popUntilHome();

    await Future.delayed(const Duration(milliseconds: 300), () async {
      if (homeNavigationTab != null) {
        unawaited(
          (homePageKey.currentState ?? homePageNoTransactionKey.currentState)
              ?.onItemTapped(homeNavigationTab.index),
        );

        await Future.delayed(const Duration(milliseconds: 300), () {
          if (exploreTab != null) {
            feralFileHomeKey.currentState?.jumpToTab(exploreTab);
          }
        });
      }
    });
  }

  Pair<String, dynamic>? _resolvePath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final parts = path.split('/')..removeWhere((element) => element.isEmpty);
    if (parts.isEmpty) {
      return null;
    }
    if (parts.length == 1) {
      return Pair(parts[0], null);
    }

    return Pair(parts[0], _resolveArgument(parts[1]));
  }

  dynamic _resolveArgument(String? argument) {
    if (argument == null || argument.isEmpty) {
      return null;
    }
    return argument;
  }

  Future<void> showEnvKeyIsMissing(List<String> keys) async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      log.info('showEnvKeyIsMissing: $keys');
      await UIHelper.showInfoDialog(
        context,
        'error'.tr(),
        'Error while reading ${keys.join(', ')}',
        onClose: () => UIHelper.hideInfoDialog(context),
      );
    }
  }

  Future<void> openPlaylist({required PlayListModel playlist}) async {
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return;
    }
    await navigatorKey.currentState?.pushNamed(
      AppRouter.viewPlayListPage,
      arguments: ViewPlaylistScreenPayload(playListModel: playlist),
    );
  }

  Future<void> showALreadyClaimPlaylist({
    required PlayListModel playlist,
  }) async {
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return;
    }
    await UIHelper.showMessageActionNew(
      context,
      'already_claimed_playlist'.tr(),
      'already_claimed_playlist_desc'.tr(),
      onClose: () => UIHelper.hideInfoDialog(context),
      isDismissible: true,
      actionButton: 'view_playlist'.tr(),
      onAction: () {
        goBack();
        openPlaylist(playlist: playlist);
      },
    );
  }

  Future<void>? showPlaylistActivationExpired() async {
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return;
    }
    await UIHelper.showMessageActionNew(
      context,
      'activation_expired'.tr(),
      'activation_expired_desc'.tr(),
      isDismissible: true,
    );
  }

  Future<void> showFlexibleDialog(
    Widget content, {
    bool isDismissible = false,
    bool isRoundCorner = true,
    Color? backgroundColor,
    int autoDismissAfter = 0,
    // FeedbackType? feedback = FeedbackType.selection,
  }) async {
    await UIHelper.showFlexibleDialog(
      context,
      content,
      isDismissible: isDismissible,
      isRoundCorner: isRoundCorner,
      backgroundColor: backgroundColor,
      autoDismissAfter: autoDismissAfter,
      // feedback: feedback,
    );
  }

  Future<void> showStreamAction(
    String displayKey,
    FutureOr<void> Function(BaseDevice device)? onDeviceSelected,
  ) async {
    await injector<NavigationService>().showFlexibleDialog(
      BlocProvider.value(
        value: injector<CanvasDeviceBloc>(),
        child: StreamDeviceView(
          displayKey: displayKey,
          onDeviceSelected: (canvasDevice) {
            onDeviceSelected?.call(canvasDevice);
          },
        ),
      ),
      isDismissible: true,
    );
  }

  Future<void> showHowToInstallDailyWidget() async {
    await injector<NavigationService>().showFlexibleDialog(
      const HowToInstallDailyWidget(),
      isDismissible: true,
    );
  }

  Future<void> openUrl(Uri uri) async {
    await _browser.openUrl(uri.toString());
  }

  Future<void> showBackupRecoveryPhraseDialog() async {
    if (context.mounted) {
      await UIHelper.showCenterSheet(
        context,
        content: PopScope(
          canPop: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  'upgrade_required'.tr(),
                  style: Theme.of(context).textTheme.ppMori700White24,
                ),
                const SizedBox(height: 50),
                SelectableText(
                  'your_device_not_support_passkey_desc'.tr(),
                  style: Theme.of(context).textTheme.ppMori400White14,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. ',
                        style: Theme.of(context).textTheme.ppMori400White14,
                      ),
                      Expanded(
                        child: SelectableText(
                          'step_1_backup_recovery'.tr(),
                          style: Theme.of(context).textTheme.ppMori400White14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. ',
                        style: Theme.of(context).textTheme.ppMori400White14,
                      ),
                      Expanded(
                        child: SelectableText(
                          'step_2_move_to_another_wallet'.tr(),
                          style: Theme.of(context).textTheme.ppMori400White14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    PrimaryButton(
                      text: 'backup_recovery_phrase'.tr(),
                      onTap: () {
                        navigateTo(
                          AppRouter.recoveryPhrasePage,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      child: GestureConstrainWidget(
                        child: Text(
                          'need_help'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .ppMori400White14
                              .copyWith(
                                color: AppColor.auQuickSilver,
                                decoration: TextDecoration.underline,
                              ),
                        ),
                      ),
                      onTap: () {
                        navigateTo(
                          AppRouter.supportThreadPage,
                          arguments: NewIssuePayload(
                            reportIssueType: ReportIssueType.Bug,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        backgroundColor: AppColor.auGreyBackground,
        withExitButton: false,
        verticalPadding: 0,
      );
    }
  }

  Future<void> showAuthenticationUpdateRequired() async {
    await UIHelper.showCenterSheet(
      context,
      content: PopScope(
        canPop: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'authentication_update_required'.tr(),
                style: Theme.of(context).textTheme.ppMori700White24,
              ),
              const SizedBox(height: 50),
              Text(
                Platform.isAndroid
                    ? 'authentication_update_required_desc_android'.tr()
                    : 'authentication_update_required_desc_ios'.tr(),
                style: Theme.of(context).textTheme.ppMori400White14,
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  PrimaryButton(
                    text: 'go_to_settings'.tr(),
                    onTap: () {
                      openAuthenticationSettings();
                    },
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    child: GestureConstrainWidget(
                      child: Text(
                        'need_help'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .ppMori400White14
                            .copyWith(
                              color: AppColor.auQuickSilver,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                    onTap: () {
                      navigateTo(
                        AppRouter.supportThreadPage,
                        arguments: NewIssuePayload(
                          reportIssueType: ReportIssueType.Bug,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColor.auGreyBackground,
      withExitButton: false,
      verticalPadding: 0,
    );
  }

  Future<JWT?> showRefreshJwtFailedDialog({
    required Future<JWT> Function() onRetry,
  }) async {
    log.info('showRefreshJwtFailedDialog');
    final res = await UIHelper.showCustomDialog<JWT>(
      context: context,
      child: PopScope(
        canPop: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'session_expired'.tr(),
              style: Theme.of(context).textTheme.ppMori700White24,
            ),
            const SizedBox(height: 20),
            Text(
              'session_expired_desc'.tr(),
              style: Theme.of(context).textTheme.ppMori400White14,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'sign_in'.tr(),
              onTap: () async {
                final jwt = await onRetry();
                if (context.mounted) {
                  Navigator.pop(context, jwt);
                }
              },
            ),
          ],
        ),
      ),
    );
    return res;
  }

  void openGoogleChatSpace() {
    _browser.openUrl(googleChatSpaceUrl);
  }

  Future<void> showLinkArtistSuccess() async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        context,
        'link_artist_success'.tr(),
        'link_artist_success_desc'.tr(),
        onClose: () => UIHelper.hideInfoDialog(context),
      );
    }
  }

  Future<void> showLinkArtistFailed(Object exception) async {
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        context,
        'link_artist_failed'.tr(),
        'link_artist_failed_desc'.tr(
          namedArgs: {
            'error': exception.toString(),
          },
        ),
        onClose: () => UIHelper.hideInfoDialog(context),
      );
    }
  }

  Future<void> openArtistDisplaySetting({Artwork? artwork}) async {
    // show a dialog with ArtistDisplaySettingWidget
    if (context.mounted) {
      UIHelper.showCustomDialog<void>(
        context: context,
        child: ArtistDisplaySettingWidget(
          artwork: artwork,
          artistDisplaySetting: null,
          onSettingChanged: (ArtistDisplaySetting) {},
        ),
        isDismissible: true,
        name: UIHelper.artistArtworkDisplaySettingModal,
      );
    }
  }

  void showArtistDisplaySettingSaved() {
    if (context.mounted) {
      UIHelper.showInfoDialog(
        context,
        'Artwork Settings Updated',
        'Your artwork settings have been successfully saved.',
      );
    }
  }

  void showArtistDisplaySettingSaveFailed({required Object exception}) {
    if (context.mounted) {
      UIHelper.showInfoDialog(
        context,
        'Failed to Save Artwork Settings',
        'Unable to save the artwork settings. '.tr() + ' $exception',
      );
    }
  }

  Future<void>? showLinkArtistTokenNotFound() async {
    await UIHelper.showInfoDialog(
      context,
      'Linking Token Expired',
      '	The token for linking the artist has expired or is missing. Please generate a new token and try again.',
    );
  }

  Future<void>? showLinkArtistAddressAlreadyLinked() {
    return UIHelper.showInfoDialog(
      context,
      'Artist Already Linked to Another User',
      'The artist is already linked to a different user via passkey. If you want to link this artist to a new user, please unlink the previous user first.',
    );
  }

  Future<void>? showLinkArtistAddressNotFound() {
    return UIHelper.showInfoDialog(
      context,
      'User Already Has a Linked Artist',
      'This user already has a linked artist. If you need to link a new artist, please unlink the current one first.',
    );
  }

  Future<void> showDeviceSettings({
    String? tokenId,
    String? artistName,
  }) async {
    if (navigatorKey.currentState != null &&
        navigatorKey.currentState!.mounted == true &&
        navigatorKey.currentContext != null) {
      if (CustomRouteObserver.bottomSheetVisibility.value) {
        Navigator.pop(navigatorKey.currentContext!);
      }

      final tokenConfiguration = tokenId != null
          ? await injector<NftIndexerService>().getTokenConfiguration(tokenId)
          : null;

      unawaited(
        UIHelper.showRawDialog(
          navigatorKey.currentContext!,
          NowDisplaySettingView(
            tokenConfiguration: tokenConfiguration,
            artistName: artistName,
            tokenId: tokenId,
          ),
          title: 'FF1 Settings',
          name: UIHelper.artDisplaySettingModal,
          isRoundCorner: false,
        ),
      );
    }
  }

  void hideDeviceSettings() {
    if (navigatorKey.currentState != null &&
        navigatorKey.currentState!.mounted == true &&
        navigatorKey.currentContext != null) {
      if (currentRoute?.isArtDisplaySettingModalShowing ?? false) {
        Navigator.pop(navigatorKey.currentContext!);
      }
    }
  }

  Future<bool> showCreateNewAccountWithExistingPasskey() async {
    final res = await UIHelper.showCenterDialog(
      context,
      showHideOtherDialog: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back! It looks like you’re starting fresh. Would you like to contniue?',
            style: Theme.of(context).textTheme.ppMori400White14,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'cancel'.tr(),
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    injector<NavigationService>().goBack(result: false);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'OK',
                  textColor: AppColor.white,
                  borderColor: AppColor.white,
                  color: Colors.transparent,
                  onTap: () async {
                    injector<NavigationService>().goBack(result: true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return (res is bool) ? res : false;
  }

  Future<void> showThePortalIsSet(
      BluetoothDevice device, Function? onTap) async {
    return UIHelper.showDialog(
      context,
      'The FF1 is All Set',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your FF1 is already set up and connected. You can head to settings to make changes or check the status.',
            style: Theme.of(context).textTheme.ppMori400White14,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            onTap: () {
              injector<NavigationService>().goBack();
              onTap?.call();
            },
            text: 'Go to Settings',
          ),
        ],
      ),
    );
  }

  // show a dialog to inform that version is not compatible, user need to update app to work with the device
  Future<void> showVersionNotCompatibleDialog() async {
    final packageInfo = await injector<VersionService>().getPackageInfo();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    final deviceName =
        BluetoothDeviceManager().castingBluetoothDevice?.getName ?? 'FF-X1';
    if (context.mounted) {
      await UIHelper.showDialog(
        context,
        'App Update Required',
        PopScope(
          canPop: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.ppMori400White14,
                  children: [
                    TextSpan(
                      text: 'App Version',
                    ),
                    TextSpan(
                      text: ' $version ($buildNumber)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' is not compatible with your ',
                    ),
                    TextSpan(
                      text: deviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          '. Please update the app to continue using your device.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PrimaryAsyncButton(
                text: 'Update Now',
                onTap: () async {
                  // Add your update logic here
                  await injector<VersionService>().openLatestVersion();
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  // show a dialog to inform that the device is not compatible, user need to update device to work with the app
  Future<void> showDeviceNotCompatibleDialog() async {
    if (context.mounted) {
      final deviceName =
          BluetoothDeviceManager().castingBluetoothDevice?.getName ?? 'FF-X1';
      await UIHelper.showDialog(
        context,
        'FF1 Software Update Needed',
        PopScope(
          canPop: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.ppMori400White14,
                  children: [
                    TextSpan(
                      text: 'Your ',
                    ),
                    TextSpan(
                      text: deviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' is running an older software version.',
                    ),
                    TextSpan(
                      text:
                          'Please update your FF1 to ensure full functionality.',
                    ),
                  ],
                ),
              ),
              // const SizedBox(height: 16),
              // PrimaryButton(
              //   text: 'Update Device',
              //   onTap: () {
              //     // Add your update logic here
              //     injector<NavigationService>().goBack();
              //   },
              // ),
            ],
          ),
        ),
      );
    }
  }
}
