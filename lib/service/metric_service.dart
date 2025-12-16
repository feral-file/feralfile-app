//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/metric/dp1_playlist_metric.dart';
import 'package:autonomy_flutter/model/metric/identify_user_payload.dart';
import 'package:autonomy_flutter/sdk/openpanel_sdk.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';
import 'package:sentry/sentry.dart';

/// Abstract service for tracking metrics and analytics using OpenPanel.
///
/// This service provides a high-level interface for tracking events,
/// identifying users, and managing user properties.
abstract class MetricService {
  /// Initialize the metric service.
  Future<void> initialize();

  /// Track an event with optional properties.
  ///
  /// [eventName] is the name of the event to track (required).
  /// [properties] are optional custom properties to attach to the event.
  ///
  /// Errors are logged but do not throw exceptions to prevent disrupting
  /// the user experience.
  Future<void> trackEvent({
    required MetricEvent event,
    Map<String, dynamic>? properties,
  });

  /// Identify a user with profile information.
  ///
  /// [profileId] is the unique identifier for the user (required).
  /// [firstName], [lastName], [email] are optional user details.
  /// [properties] are optional custom properties to attach to the profile.
  ///
  /// Errors are logged but do not throw exceptions to prevent disrupting
  /// the user experience.
  Future<void> identifyUser({
    required String profileId,
    required IdentifyUserPayload payload,
  });

  /// Update user agent for device information tracking.
  ///
  /// [userAgent] is the user agent string. Pass null to remove.
  void setUserAgent(String? userAgent);
}

/// Implementation of MetricService using OpenPanel SDK.
class MetricServiceImpl implements MetricService {
  MetricServiceImpl();

  late OpenPanelSdk _openPanelSdk;

  bool _isInitialized = false;

  /// Initialize user agent from device info if available.
  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _openPanelSdk = OpenPanelSdk(
      clientId: Environment.openPanelClientId,
      clientSecret: Environment.openPanelClientSecret,
      baseUrl: Environment.openPanelApiUrl,
    );
    _isInitialized = true;
    // identify user
    final userId = await injector<AuthService>().getOrGenerateUserId();
    await identifyUser(
      profileId: userId,
      payload: IdentifyUserPayload(
        actorType: ActorType.ffController,
        actorId: userId,
      ),
    );
  }

  @override
  Future<void> trackEvent({
    required MetricEvent event,
    Map<String, dynamic>? properties,
  }) async {
    if (!_isInitialized) {
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage(
          'MetricService not initialized',
        ),
        level: SentryLevel.warning,
      ));
      return;
    }

    try {
      await _openPanelSdk.track(
        name: event.name,
        properties: properties,
      );
      log.fine('[MetricService] Tracked event: ${event.name}');
    } on DioException catch (e) {
      log.warning(
        '[MetricService] Failed to track event "${event.name}": ${e.message}',
      );
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage(
          'Failed to track event "${event.name}": ${e.message}',
        ),
        level: SentryLevel.warning,
      )));
    } catch (e) {
      log.warning(
        '[MetricService] Unexpected error tracking event "${event.name}": $e',
      );
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage(
          'Unexpected error tracking event "${event.name}": $e',
        ),
        level: SentryLevel.warning,
      )));
    }
  }

  @override
  Future<void> identifyUser({
    required String profileId,
    required IdentifyUserPayload payload,
  }) async {
    try {
      if (!_isInitialized) {
        Sentry.captureEvent(SentryEvent(
          message: SentryMessage(
            'MetricService not initialized',
          ),
          level: SentryLevel.warning,
        ));
        return;
      }
      await _openPanelSdk.identify(
        profileId: profileId,
        properties: payload.toJson(),
      );
      log.fine('[MetricService] Identified user: $profileId');
    } on DioException catch (e) {
      log.warning(
        '[MetricService] Failed to identify user "$profileId": ${e.message}',
      );
    } catch (e) {
      log.warning(
        '[MetricService] Unexpected error identifying user "$profileId": $e',
      );
    }
  }

  @override
  void setUserAgent(String? userAgent) {
    if (!_isInitialized) {
      Sentry.captureEvent(SentryEvent(
        message: SentryMessage(
          'MetricService not initialized',
        ),
        level: SentryLevel.warning,
      ));
      return;
    }
    _openPanelSdk.setUserAgent(userAgent);
  }
}

enum MetricEvent {
  view_playlist;

  String get name {
    switch (this) {
      case MetricEvent.view_playlist:
        return 'playlist_view';
    }
  }
}
