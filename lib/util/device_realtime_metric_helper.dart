import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:rxdart/rxdart.dart';

class DeviceRealtimeMetricHelper {
  factory DeviceRealtimeMetricHelper() {
    return _instance;
  }

  DeviceRealtimeMetricHelper._internal();

  // singleton
  static final DeviceRealtimeMetricHelper _instance =
      DeviceRealtimeMetricHelper._internal();

  final Map<String, StreamController<DeviceRealtimeMetrics>>
      _deviceRealtimeMetricsControllers = {};

  final Map<String, Timer> _deviceTimers = {};

  Stream<DeviceRealtimeMetrics> getDeviceRealtimeMetricsStream(
      BaseDevice device) {
    final controller =
        _deviceRealtimeMetricsControllers[device.deviceId]?.stream;
    if (controller != null) {
      return controller;
    } else {
      final newController = StreamController<DeviceRealtimeMetrics>.broadcast();
      _deviceRealtimeMetricsControllers[device.deviceId] = newController;
      return newController.stream;
    }
  }

  void dispose() {
    // Cancel all timers
    for (var timer in _deviceTimers.values) {
      timer.cancel();
    }
    _deviceTimers.clear();

    // Close all stream controllers
    for (var controller in _deviceRealtimeMetricsControllers.values) {
      controller.close();
    }
    _deviceRealtimeMetricsControllers.clear();
  }

  Stream<DeviceRealtimeMetrics> startMetrics(BaseDevice device) {
    if (_deviceTimers.containsKey(device.deviceId)) {
      return _deviceRealtimeMetricsControllers[device.deviceId]!.stream;
    }

    final controller = _deviceRealtimeMetricsControllers[device.deviceId] ??
        StreamController<DeviceRealtimeMetrics>.broadcast();
    _deviceRealtimeMetricsControllers[device.deviceId] = controller;

    _deviceTimers[device.deviceId]?.cancel();
    // Simulate periodic metrics updates
    final timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      DeviceRealtimeMetrics? metrics;
      if (injector<CanvasDeviceBloc>().state.isDeviceAlive(device)) {
        metrics = await injector<CanvasClientServiceV2>()
            .getDeviceRealtimeMetrics(device);
      } else {
        log.info(
            '[DeviceRealtimeMetricHelper][startMetrics] Timer: Device ${device.name} is not alive');
      }
      if (metrics == null) {
        return;
      }
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      if (controller.isPaused) {
        return;
      }
      controller.add(metrics);
    });

    _deviceTimers[device.deviceId] = timer;
    return controller.stream;
  }

  void stopMetrics(BaseDevice device) {
    if (_deviceTimers.containsKey(device.deviceId)) {
      _deviceTimers[device.deviceId]!.cancel();
      _deviceTimers.remove(device.deviceId);
    }
    if (_deviceRealtimeMetricsControllers.containsKey(device.deviceId)) {
      _deviceRealtimeMetricsControllers[device.deviceId]!.close();
      _deviceRealtimeMetricsControllers.remove(device.deviceId);
    }
  }
}

class RealtimeMetricsManager {
  RealtimeMetricsManager._();

  static final RealtimeMetricsManager _instance = RealtimeMetricsManager._();

  factory RealtimeMetricsManager() => _instance;

  final _deviceController = BehaviorSubject<BaseDevice>();

  late final Stream<DeviceRealtimeMetrics> _realtimeMetricsStream =
      _deviceController.switchMap(
    (device) => DeviceRealtimeMetricHelper().startMetrics(device),
  );

  BaseDevice? _currentDevice;

  /// The public stream — listen to this only once
  Stream<DeviceRealtimeMetrics> get realtimeMetricsStream =>
      _realtimeMetricsStream;

  /// Start the first device
  Stream<DeviceRealtimeMetrics> startRealtimeMetrics() {
    final device = BluetoothDeviceManager().castingBluetoothDevice;
    if (device == null) {
      throw Exception('No casting device found');
    }
    _currentDevice = device;
    _deviceController.add(device);
    return realtimeMetricsStream;
  }

  /// Switch to a different device
  void switchRealtimeMetrics(BaseDevice device) {
    stopRealtimeMetrics();
    _currentDevice = device;
    _deviceController.add(device);
  }

  /// Stop current metrics
  void stopRealtimeMetrics() {
    if (_currentDevice == null) {
      log.info('No current device to stop metrics for');
      return;
    }
    DeviceRealtimeMetricHelper().stopMetrics(_currentDevice!);
    _currentDevice = null;
  }

  void dispose() {
    _deviceController.close();
  }
}
