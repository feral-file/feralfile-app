// ignore_for_file: avoid_annotating_with_dynamic

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/iap_api.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/metric_helper.dart';
import 'package:sentry/sentry.dart';

class MetricClientService {
  MetricClientService();

  String _identifier = '';

  String _defaultIdentifier() => injector<DeviceInfoService>().deviceId;

  Future<void> initService({String? identifier}) async {
    log.info('[MetricClientService] initService');
    _identifier = identifier ?? _defaultIdentifier();
  }

  Future<void> identity() async {
    log.info('[MetricClientService] identity');
    try {
      final userId = injector<AuthService>().getUserId();
      if (userId == null) {
        log.info('Metric Identity: userId is null');
        unawaited(Sentry.captureMessage('Metric Identity: userId is null'));
        return;
      }
      await mergeUser(_identifier);
    } catch (e) {
      log.info('Metric identity error: $e');
      unawaited(Sentry.captureException('Metric identity error: $e'));
    }
  }

  Future<void> addEvent(
    MetricEventName event, {
    String? message,
    Map<MetricParameter, dynamic> data = const {},
    Map<String, dynamic> hashedData = const {},
  }) async {
    return;
    log.info('[MetricClientService] addEvent: ${event.name}');
    final configurationService = injector.get<ConfigurationService>();

    if (!configurationService.isAnalyticsEnabled()) {
      return;
    }
    final rawData = data.map((key, value) => MapEntry(key.name, value));

    // ignore: unused_local_variable
    final dataWithExtend = {
      'event': event.name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'parameters': {
        ...rawData,
        'platform': platform,
        'device': {
          'osVersion': injector<DeviceInfoService>().deviceOSVersion,
        },
      }
    };

    final metrics = {
      'metrics': [
        dataWithExtend,
      ]
    };
    try {
      // await injector<IAPApi>().sendEvent(
      //   metrics,
      //   _identifier,
      //   // TODO: add device info
      //   // injector<DeviceInfoService>().deviceName,
      //   // injector<DeviceInfoService>().deviceVendor,
      //   // injector<DeviceInfoService>().deviceModel,
      //   // injector<DeviceInfoService>().deviceOSName,
      // );
      log.info('Metric add event success: ${event.name}');
    } catch (e) {
      log.info('Metric add event error: $e');
      unawaited(Sentry.captureException('Metric add event error: $e'));
    }
  }

  void timerEvent(String name) {
    // time event here
  }

  Future<void> mergeUser(String oldUserId) async {
    // new userId will include in jwt token
    // await injector<IAPApi>().updateMetrics(oldUserId);
  }

  void setLabel(String prop, dynamic value) {
    // mixPanelClient.setLabel(prop, value);
  }

  void incrementPropertyLabel(String prop, double value) {
    // mixPanelClient.incrementPropertyLabel(prop, value);
  }

  Future<void> reset() async {
    try {
      return;
      final deviceId = _defaultIdentifier();
      await injector<IAPApi>().deleteMetrics(deviceId);
    } catch (e) {
      unawaited(Sentry.captureException('Metric reset error: $e'));
    }
  }
}
