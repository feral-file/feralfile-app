//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry/sentry.dart';

/// Centralized OneSignal bootstrap to avoid using the SDK when misconfigured.
///
/// We have seen production/TestFlight crashes when OneSignal is initialized with
/// an empty App ID (e.g., missing `.env` secret at build time). This guard makes
/// OneSignal usage a no-op in that scenario.
class OneSignalBootstrap {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static bool get canUseOneSignal =>
      Environment.onesignalAppID.isNotEmpty && _isInitialized;

  static Future<void> initializeIfPossible() async {
    if (_isInitialized) {
      return;
    }

    final appId = Environment.onesignalAppID;
    if (appId.isEmpty) {
      log.warning('OneSignal disabled: ONESIGNAL_APP_ID is missing');
      unawaited(
        Sentry.captureMessage(
            'OneSignal disabled: ONESIGNAL_APP_ID is missing'),
      );
      return;
    }

    try {
      if (!Platform.isAndroid) {
        return;
      }
      OneSignal.Debug.setLogLevel(OSLogLevel.error);
      OneSignal.initialize(appId);

      // Safety: we have seen native crashes originating from the OneSignal
      // In-App Messages stack in production/TestFlight.
      // Pausing IAM avoids the fetch/display pipeline until we explicitly resume.
      await OneSignal.InAppMessages.paused(true);

      _isInitialized = true;
      log.info('OneSignal initialized successfully');
    } catch (e, stackTrace) {
      log.severe('Error initializing OneSignal: $e', e, stackTrace);
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }
}

Future<bool> registerPushNotifications({bool askPermission = false}) async {
  log.info('register notification');
  if (!OneSignalBootstrap.canUseOneSignal) {
    log.warning('Skipping notification registration: OneSignal not ready');
    return false;
  }
  if (askPermission) {
    final permission = Platform.isAndroid
        ? true
        : await OneSignal.Notifications.requestPermission(true);

    if (!permission) {
      return false;
    }
  }

  try {
    final userId = injector<AuthService>().getUserId();
    if (userId == null || userId.isEmpty) {
      log.warning('Skipping OneSignal login: user ID is missing');
      return false;
    }

    await OneSignal.login(userId);
    if (injector<AppDataManager>()
            .appSettingsStorageService
            .isNotificationEnabled &&
        OneSignal.Notifications.permission) {
      await OneSignal.User.pushSubscription.optIn();
    }
    return true;
  } catch (error) {
    unawaited(
      Sentry.captureException(
        'error when registering notifications: $error',
      ),
    );
    log.warning('error when registering notifications: $error');
    return false;
  }
}

Future<void> deregisterPushNotification() async {
  log.info('unregister notification');
  if (!OneSignalBootstrap.canUseOneSignal) {
    log.warning('Skipping notification deregistration: OneSignal not ready');
    return;
  }
  await OneSignal.User.pushSubscription.optOut();
  await OneSignal.logout();
}

class OneSignalHelper {
  static Future<void> setExternalUserId({
    required String userId,
    String? authHashToken,
  }) async {
    if (!OneSignalBootstrap.canUseOneSignal) {
      log.warning('Skipping OneSignal login: OneSignal not ready');
      return;
    }
    await OneSignal.login(userId);
  }
}
