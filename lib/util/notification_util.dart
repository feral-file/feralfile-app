//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sentry/sentry.dart';

Future<bool> registerPushNotifications({bool askPermission = false}) async {
  log.info('register notification');
  if (askPermission) {
    final permission = Platform.isAndroid
        ? true
        : await OneSignal.Notifications.requestPermission(true);

    if (!permission) {
      return false;
    }
  }

  try {
    // final userId = injector<AuthService>().getUserId();
    // TODO: Get user id
    const userId = '';
    await OneSignal.login(userId!);
    if (injector<ConfigurationService>().isNotificationEnabled() &&
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
  await OneSignal.User.pushSubscription.optOut();
  await OneSignal.logout();
}
