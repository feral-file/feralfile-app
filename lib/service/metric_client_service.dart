// ignore_for_file: avoid_annotating_with_dynamic

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/metric_helper.dart';
import 'package:sentry/sentry.dart';

// TODO: Remove metric

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
    // Authentication removed - identity tracking no longer needed
  }

  Future<void> addEvent(
    MetricEventName event, {
    String? message,
    Map<MetricParameter, dynamic> data = const {},
    Map<String, dynamic> hashedData = const {},
  }) async {
    return;
  }

  void timerEvent(String name) {
    // time event here
  }

  Future<void> mergeUser(String oldUserId) async {
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
    } catch (e) {
      unawaited(Sentry.captureException('Metric reset error: $e'));
    }
  }
}
