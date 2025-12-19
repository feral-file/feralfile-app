// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //
//
// import 'dart:async';
//
// import 'package:autonomy_flutter/common/injector.dart';
// import 'package:autonomy_flutter/service/auth_service.dart';
// import 'package:autonomy_flutter/util/log.dart';
// import 'package:onesignal_flutter/onesignal_flutter.dart';
// import 'package:sentry/sentry.dart';
//
// import 'notification_util.dart';
//
// /// Service for managing push notification subscriptions and preferences
// abstract class NotificationService {
//   /// Login user to OneSignal with user ID
//   /// Returns true if login successful, false otherwise
//   Future<bool> login(String userId);
//
//   /// Opt in to receive push notifications
//   Future<bool> optIn();
//
//   /// Opt out from receiving push notifications
//   Future<bool> optOut();
//
//   /// Register device for push notifications with optional permission request
//   /// Returns true if registration successful, false otherwise
//   Future<bool> registerPushNotifications({bool askPermission = false});
//
//   /// Unregister device from push notifications
//   Future<void> unregisterPushNotification();
//
//   /// Check if user is currently opted in for notifications
//   bool isOptedIn();
// }
//
// class NotificationServiceImpl implements NotificationService {
//   final AuthService _authService;
//
//   NotificationServiceImpl() : _authService = injector<AuthService>();
//
//   @override
//   Future<bool> login(String userId) async {
//     log.info('NotificationService: login with user ID: $userId');
//     if (!OneSignalBootstrap.canUseOneSignal) {
//       log.warning('NotificationService: OneSignal not ready, skip login');
//       return false;
//     }
//     try {
//       await OneSignal.login(userId);
//       log.info('NotificationService: login successful');
//       return true;
//     } catch (error) {
//       unawaited(
//         Sentry.captureException(
//           'NotificationService: error logging in: $error',
//         ),
//       );
//       log.warning('NotificationService: error logging in: $error');
//       return false;
//     }
//   }
//
//   @override
//   Future<bool> optIn() async {
//     log.info('NotificationService: opt in');
//     if (!OneSignalBootstrap.canUseOneSignal) {
//       log.warning('NotificationService: OneSignal not ready, skip opt in');
//       return false;
//     }
//     try {
//       // Check if notification permission is granted
//       if (!OneSignal.Notifications.permission) {
//         log.warning('NotificationService: permission not granted');
//         return false;
//       }
//
//       await OneSignal.User.pushSubscription.optIn();
//       log.info('NotificationService: opt in successful');
//       return true;
//     } catch (error) {
//       unawaited(
//         Sentry.captureException(
//           'NotificationService: error opting in: $error',
//         ),
//       );
//       log.warning('NotificationService: error opting in: $error');
//       return false;
//     }
//   }
//
//   @override
//   Future<bool> optOut() async {
//     log.info('NotificationService: opt out');
//     if (!OneSignalBootstrap.canUseOneSignal) {
//       log.warning('NotificationService: OneSignal not ready, skip opt out');
//       return false;
//     }
//     try {
//       await OneSignal.User.pushSubscription.optOut();
//       log.info('NotificationService: opt out successful');
//       return true;
//     } catch (error) {
//       unawaited(
//         Sentry.captureException(
//           'NotificationService: error opting out: $error',
//         ),
//       );
//       log.warning('NotificationService: error opting out: $error');
//       return false;
//     }
//   }
//
//   @override
//   Future<bool> registerPushNotifications({bool askPermission = false}) async {
//     log.info('NotificationService: register push notifications');
//     if (!OneSignalBootstrap.canUseOneSignal) {
//       log.warning('NotificationService: OneSignal not ready, skip register');
//       return false;
//     }
//
//     // Request permission if needed
//     if (askPermission) {
//       final permission = await OneSignal.Notifications.requestPermission(true);
//
//       if (!permission) {
//         log.warning('NotificationService: permission denied');
//         return false;
//       }
//     }
//
//     try {
//       // Login user to OneSignal
//       final userId = _authService.getUserId();
//       if (userId == null) {
//         log.warning('NotificationService: user ID not found');
//         return false;
//       }
//
//       await OneSignal.login(userId);
//       log.info('NotificationService: logged in with user ID: $userId');
//
//       // Opt in if notifications are enabled in settings
//       if (OneSignal.Notifications.permission) {
//         await OneSignal.User.pushSubscription.optIn();
//         log.info('NotificationService: opted in automatically');
//       }
//
//       return true;
//     } catch (error) {
//       unawaited(
//         Sentry.captureException(
//           'NotificationService: error registering: $error',
//         ),
//       );
//       log.warning('NotificationService: error registering: $error');
//       return false;
//     }
//   }
//
//   @override
//   Future<void> unregisterPushNotification() async {
//     log.info('NotificationService: unregister push notification');
//     if (!OneSignalBootstrap.canUseOneSignal) {
//       log.warning('NotificationService: OneSignal not ready, skip unregister');
//       return;
//     }
//     try {
//       await OneSignal.User.pushSubscription.optOut();
//       await OneSignal.logout();
//       log.info('NotificationService: unregistered successfully');
//     } catch (error) {
//       unawaited(
//         Sentry.captureException(
//           'NotificationService: error unregistering: $error',
//         ),
//       );
//       log.warning('NotificationService: error unregistering: $error');
//     }
//   }
//
//   @override
//   bool isOptedIn() {
//     final isOptedIn = OneSignal.User.pushSubscription.optedIn ?? false;
//     log.info('NotificationService: opted in status: $isOptedIn');
//     return isOptedIn;
//   }
// }
