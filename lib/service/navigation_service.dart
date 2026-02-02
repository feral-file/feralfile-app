//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/github_doc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/all_playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/feral_file_custom_tab.dart';
import 'package:autonomy_flutter/util/log.dart' as log_util;
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/native_log_reader.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/now_displaying/now_display_setting.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:open_settings_plus/open_settings_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    log.info('NavigationService.navigateTo: $routeName');
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null ||
        !navigatorState.mounted ||
        navigatorKey.currentContext == null) {
      return Future.value(null);
    }

    return navigatorState.pushNamed(routeName, arguments: arguments);
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

  Future<dynamic>? pushReplacementNamed(String routeName, {Object? arguments}) {
    log.info('NavigationService.pushReplacementNamed: $routeName');
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return null;
    }

    return navigatorKey.currentState
        ?.pushReplacementNamed(routeName, arguments: arguments);
  }

  // create a function to replace all current route and push a new route
  Future<dynamic>? replaceAllAndPushNamed(String routeName,
      {Object? arguments}) {
    log.info('NavigationService.replaceAllAndPushNamed: $routeName');
    if (navigatorKey.currentState?.mounted != true ||
        navigatorKey.currentContext == null) {
      return null;
    }
    // Pop all routes and push a new one
    return navigatorKey.currentState?.pushNamedAndRemoveUntil(
        routeName, (route) => false,
        arguments: arguments);
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
      await settings.bluetooth();
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
      // ignore: unused_local_variable
      final theme = Theme.of(context);
      unawaited(Sentry.captureMessage('App Load Error'));
      await UIHelper.showDialog<Widget>(
        context,
        'App Load Error',
        Column(
          children: [
            SelectableText(
              'it_seem_loading_issue'.tr(),
              style: AppTypography.body(context).white,
            ),
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: AppTypography.body(context).white,
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
    Object? _error,
  ) async {
    hideInfoDialog();
    if (navigatorKey.currentContext != null &&
        navigatorKey.currentState?.mounted == true) {
      await UIHelper.showInfoDialog(
        context,
        'Unable to connect to ${device.getName}.',
        'Check the Bluetooth connection and try again.',
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

  Future<void> navigatePath(String? path) async {
    final pair = _resolvePath(path);
    if (pair == null) {
      return;
    }
    late String route;
    switch (pair.first) {
      default:
        route = pair.first;
        unawaited(navigateTo(route, arguments: pair.second));
        return;
    }
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

  Future<void> openUrl(Uri uri) async {
    await _browser.openUrl(uri.toString());
  }

  void openGoogleChatSpace() {
    _browser.openUrl(googleChatSpaceUrl);
  }

  void openFF1GroupIo() {
    _browser.openUrl(ff1GroupIoUrl);
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
      unawaited(
        UIHelper.showRawDialog(
          navigatorKey.currentContext!,
          const NowDisplayingQuickSettingView(),
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
            style: AppTypography.body(context).white,
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
        BluetoothDeviceManager().castingBluetoothDevice?.getName ?? 'FF1';
    if (context.mounted) {
      await UIHelper.showDialog<Widget>(
        context,
        'App Update Required',
        PopScope(
          canPop: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTypography.body(context).white,
                  children: [
                    const TextSpan(
                      text: 'App Version',
                    ),
                    TextSpan(
                      text: ' $version ($buildNumber)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: ' is not compatible with your ',
                    ),
                    TextSpan(
                      text: deviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
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
          BluetoothDeviceManager().castingBluetoothDevice?.getName ?? 'FF1';
      await UIHelper.showDialog<Widget>(
        context,
        'FF1 Software Update Needed',
        PopScope(
          canPop: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: AppTypography.body(context).white,
                  children: [
                    const TextSpan(
                      text: 'Your ',
                    ),
                    TextSpan(
                      text: deviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text: ' is running an older software version.',
                    ),
                    const TextSpan(
                      text:
                          'Please update your FF1 to ensure full functionality.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void openMyCollection() {
    popUntilHome();
    navigateTo(AppRouter.allPlaylistsPage,
        arguments:
            const AllPlaylistsPagePayload(playlistType: PlaylistType.me));
  }

  /// Show customer support flow:
  /// 1. Ask whether to attach a debug log
  /// 2. Prepare an email draft with prefilled subject, body and optional logs
  Future<void> showCustomerSupport() async {
    if (!mounted) {
      return;
    }

    unawaited(
      UIHelper.showDialog<void>(
        context,
        'Attach a debug log?',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended. It helps us fix issues faster by including technical details like app events, device model, and recent errors. It does not include passwords or private keys. After the email opens, you can also attach screenshots or photos.',
              style: AppTypography.body(context).white,
            ),
            SizedBox(height: LayoutConstants.space6),
            PrimaryButton(
              text: 'Attach debug log',
              onTap: () => _onConfirmAttachCrashLog(true),
            ),
            SizedBox(height: LayoutConstants.space3),
            OutlineButton(
              text: 'Send without log',
              onTap: () => _onConfirmAttachCrashLog(false),
            ),
            SizedBox(height: LayoutConstants.space4),
          ],
        ),
        isDismissible: true,
      ),
    );
  }

  void _onConfirmAttachCrashLog(bool attachCrashLog) {
    try {
      UIHelper.hideInfoDialog(context);
    } catch (e) {
      log_util.log.warning('Failed to hide attach crash log dialog: $e');
    }

    unawaited(_sendSupportEmail(attachLogs: attachCrashLog));
  }

  Future<void> _sendSupportEmail({
    required bool attachLogs,
  }) async {
    try {
      if (!mounted) {
        return;
      }

      UIHelper.showDialog<void>(
        context,
        'Preparing log files',
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final logFiles = attachLogs ? await _collectLogFiles() : <File>[];

      if (!mounted) {
        return;
      }
      UIHelper.hideInfoDialog(context);

      if (attachLogs && logFiles.isEmpty) {
        await UIHelper.showInfoDialog(
          context,
          'No log files available',
          'Unable to collect log files. Please try again later.',
        );
      }

      // Get app and user info for subject/body
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      final userId = await injector<AuthService>().getOrGenerateUserId();
      final deviceInfoService = injector<DeviceInfoService>();
      final deviceName = deviceInfoService.deviceName;
      final osName = deviceInfoService.deviceOSName;
      final osVersion = deviceInfoService.deviceOSVersion;

      final allDevices = BluetoothDeviceManager.pairedDevices;
      final castingDevice = BluetoothDeviceManager().castingBluetoothDevice;
      final castingDeviceId = castingDevice?.deviceId;
      final ff1DeviceId = castingDevice?.getName ?? 'unknown (not connected)';

      const shortSummary = 'Support request';

      final subject =
          'Support: $shortSummary — App $appVersion ($buildNumber) — Device $ff1DeviceId';

      final yesNoLog = attachLogs ? 'yes' : 'no';

      final buffer = StringBuffer()
        ..writeln('What happened? (1 sentence)')
        ..writeln('-')
        ..writeln()
        ..writeln(
          'If you can, attach a screenshot or short screen recording to this email.',
        )
        ..writeln()
        ..writeln('I was trying to: (pick one)')
        ..writeln('- Setup FF1 Wi-Fi')
        ..writeln('- Connect phone → FF1')
        ..writeln('- Play an artwork')
        ..writeln('- Play a playlist')
        ..writeln('- Play My Collection')
        ..writeln('- Other:')
        ..writeln()
        ..writeln('Auto details')
        ..writeln('- App: $appVersion ($buildNumber)')
        ..writeln('- Phone: $deviceName • $osName $osVersion');

      if (allDevices.isNotEmpty) {
        buffer.writeln('- FF1 devices:');
        for (final device in allDevices) {
          final isSelected = device.deviceId == castingDeviceId;
          final marker = isSelected ? '[selected]' : '-';
          buffer.writeln(
            '     - ${device.deviceId} $marker',
          );
        }
      } else {
        buffer.writeln('- FF1 devices: none (not paired)');
      }

      buffer
        ..writeln('- User ID: $userId')
        ..writeln('- Debug log attached: $yesNoLog')
        ..writeln();

      final emailBody = buffer.toString();

      final remoteConfigService = injector<RemoteConfigService>();
      final recipients = remoteConfigService.getConfig<List<String>>(
        ConfigGroup.support,
        ConfigKey.supportEmailRecipients,
        <String>['support@feralfile.com'],
        parser: (dynamic value) =>
            (value as List<dynamic>).map((dynamic e) => e.toString()).toList(),
      );
      final cc = remoteConfigService.getConfig<List<String>>(
        ConfigGroup.support,
        ConfigKey.supportEmailCc,
        <String>[],
        parser: (dynamic value) =>
            (value as List<dynamic>).map((dynamic e) => e.toString()).toList(),
      );

      final email = Email(
        body: emailBody,
        subject: subject,
        recipients: recipients,
        cc: cc,
        attachmentPaths: logFiles.map((file) => file.path).toList(),
        isHTML: false,
      );

      await FlutterEmailSender.send(email);
      log_util.log.info('Email sent successfully');
    } catch (e, s) {
      log_util.log.severe('Failed to handle contact us: $e');
      await Sentry.captureException(
        'Failed to handle contact us: $e',
        stackTrace: s,
      );
      if (!mounted) {
        return;
      }
      UIHelper.hideInfoDialog(context);
      await UIHelper.showInfoDialog(
        context,
        'Error',
        'Failed to prepare email. Please try again later.',
      );
    }
  }

  Future<List<File>> _collectLogFiles() async {
    final List<File> logFiles = [];
    const fileMaxSize = 1024 * 1024; // 1MB

    // Get Flutter logs
    try {
      final file = await log_util.getLogFile();
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        var combinedBytes = bytes;
        if (combinedBytes.length > fileMaxSize) {
          combinedBytes =
              combinedBytes.sublist(combinedBytes.length - fileMaxSize);
        }
        if (combinedBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/flutter_${combinedBytes.length}_${DateTime.now().microsecondsSinceEpoch}.logs',
          );
          await tempFile.writeAsBytes(combinedBytes);
          logFiles.add(tempFile);
        }
      }
    } catch (e) {
      log_util.log.severe('Failed to get Flutter log: $e');
    }

    // Get native logs (Android only)
    try {
      if (Platform.isAndroid) {
        final nativeLogContent = await NativeLogReader.getLogContent();
        final nativeLogBytes = utf8.encode(nativeLogContent);
        var nativeLogCombinedBytes = nativeLogBytes;
        if (nativeLogCombinedBytes.length > fileMaxSize) {
          nativeLogCombinedBytes = nativeLogCombinedBytes
              .sublist(nativeLogCombinedBytes.length - fileMaxSize);
        }
        if (nativeLogCombinedBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(
            '${tempDir.path}/native_${nativeLogCombinedBytes.length}_${DateTime.now().microsecondsSinceEpoch}.logs',
          );
          await tempFile.writeAsBytes(nativeLogCombinedBytes);
          logFiles.add(tempFile);
        }
      }
    } catch (e) {
      log_util.log.severe('Failed to get native log: $e');
    }

    // Add account settings audit log
    try {
      final accountSettingsAudit = await _generateAccountSettingsAudit();
      final auditBytes = utf8.encode(accountSettingsAudit);
      if (auditBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/account_settings_audit_${auditBytes.length}_${DateTime.now().microsecondsSinceEpoch}.json',
        );
        await tempFile.writeAsBytes(auditBytes);
        logFiles.add(tempFile);
      }
    } catch (e) {
      log_util.log.severe('Failed to get account settings audit: $e');
    }

    return logFiles;
  }

  Future<String> _generateAccountSettingsAudit() async {
    try {
      final appDataManager = injector<AppDataManager>();

      // Gather account settings with privacy protection
      final auditData = <String, dynamic>{
        'app_preferences': _gatherAppPreferences(appDataManager),
        'addresses_import_history': _gatherAccountHistory(appDataManager),
      };

      // Convert to JSON with pretty printing
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(auditData);
    } catch (e) {
      log_util.log.severe('Failed to generate account settings audit: $e');
      return '{"error": "Failed to generate account settings audit: $e"}';
    }
  }

  Map<String, dynamic> _gatherAppPreferences(AppDataManager appDataManager) {
    try {
      final settingsService = appDataManager.appSettingsStorageService;

      return {
        'analytics_enabled': settingsService.isAnalyticsEnabled,
        'notification_enabled': settingsService.isNotificationEnabled,
        'device_passcode_enabled': settingsService.isDevicePasscodeEnabled,
        'beta_features_enabled': settingsService.isBetaFeaturesEnabled,
        'explore_bar_enabled': settingsService.isExploreBarEnabled,
        'hidden_token_count': settingsService.hiddenTokenIDs.length,
        'selected_device_id': settingsService.selectedDeviceId ?? 'none',
      };
    } catch (e) {
      log_util.log.warning('Failed to gather app preferences: $e');
      return {'error': 'Unable to retrieve preferences'};
    }
  }

  Map<String, dynamic> _gatherAccountHistory(AppDataManager appDataManager) {
    try {
      final addressService = appDataManager.addressStorageService;

      // Get address-related info without exposing private keys
      final addresses = addressService.getAllAddresses();

      return {
        'total_addresses': addresses.length,
        'address_details': addresses
            .map((addr) => {
                  'type': addr.cryptoType.toString(),
                  'created_at': addr.createdAt.toIso8601String(),
                  'is_hidden': addr.isHidden,
                  'name': addr.name,
                  // Redact actual address for privacy
                  'address_preview': _redactAddress(addr.address),
                })
            .toList(),
      };
    } catch (e) {
      log_util.log.warning('Failed to gather account history: $e');
      return {'error': 'Unable to retrieve account history'};
    }
  }

  String _redactAddress(String address) {
    // Show first 6 and last 4 characters only, redact the middle
    if (address.length <= 10) {
      return '***';
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Show firmware update dialog with engineering voice compliant content.
  /// Returns true if user tapped Update, false if Cancel, null if dialog was dismissed.
  Future<bool?> showFirmwareUpdateDialog(
    DeviceStatus deviceStatus, {
    bool saveDismissedOnCancel = true,
  }) async {
    if (!mounted) {
      return null;
    }

    final latestVersion = deviceStatus.latestVersion;

    final firmwareMessageParagraphs = <String>[
      'A new update is available for your FF1.',
      if (latestVersion != null && latestVersion.isNotEmpty)
        'Update to version $latestVersion.',
      'Your FF1 will restart to complete the update.',
    ];

    final result = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FFOS update available',
            style: AppTypography.body(context).bold.white,
          ),
          const SizedBox(height: 16),
          Text(
            firmwareMessageParagraphs.join('\n\n'),
            style: AppTypography.body(context).white,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Later',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () async {
                    if (saveDismissedOnCancel) {
                      final nowMillis = DateTime.now().millisecondsSinceEpoch;
                      await injector<ConfigurationService>()
                          .setDismissedFirmwareUpdateAt(nowMillis);
                    }
                    goBack(result: false);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Update',
                  textColor: AppColor.primaryBlack,
                  color: AppColor.feralFileLightBlue,
                  onTap: () async {
                    final device =
                        BluetoothDeviceManager().castingBluetoothDevice;
                    if (device != null && mounted) {
                      try {
                        await injector<CanvasClientServiceV2>()
                            .updateToLatestVersion(device);
                        if (mounted) {
                          goBack(result: true);
                          // Show success message
                          UIHelper.showDialog<void>(
                            context,
                            'Update started',
                            Text(
                              'Your FF1 is currently updating, and depending on the OS version, the update may run in the background without visible on-screen activity.',
                              style: AppTypography.body(context).white,
                            ),
                          );
                        }
                        final nowMillis = DateTime.now().millisecondsSinceEpoch;
                        await injector<ConfigurationService>()
                            .setLastFf1OsUpdateAt(nowMillis);
                        if (saveDismissedOnCancel) {
                          await injector<ConfigurationService>()
                              .setDismissedFirmwareUpdateAt(nowMillis);
                        }
                      } catch (e) {
                        log.warning('Failed to update firmware: $e');
                        if (mounted) {
                          goBack();
                          UIHelper.showDialog<void>(
                            context,
                            'Update failed',
                            Text(
                              'The FFOS update couldn\'t start. '
                              'Try again later.',
                              style: AppTypography.body(context).white,
                            ),
                          );
                        }
                      }
                    } else {
                      goBack(result: false);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Cast result to bool? (false for Cancel, true for Update, null for dismissed)
    if (result is bool) {
      return result;
    }
    return null;
  }
}
