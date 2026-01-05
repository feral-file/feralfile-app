import 'dart:async';
import 'dart:isolate';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/ff1_relayer_notification/ff1_relayer_main_to_isolate.dart';
import 'package:autonomy_flutter/model/ff1_relayer_notification/ff1_relayer_isolate_to_main.dart';
import 'package:autonomy_flutter/service/canvas_notification_isolate.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/log.dart';

class CanvasNotificationService {
  CanvasNotificationService(this._device);

  final _notificationController = StreamController<RelayerMessage>.broadcast();
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _lastError;
  bool _isConnecting = false;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSub;
  SendPort? _isolateSendPort;
  Completer<void>? _isolateReadyCompleter;

  // basedevice
  final BaseDevice _device;

  Stream<RelayerMessage> get notificationStream =>
      _notificationController.stream;

  Future<bool> connect() async {
    if (_isConnected) {
      return true;
    }
    if (_isConnecting) {
      // Avoid multiple concurrent connect calls.
      return _isConnected;
    }

    try {
      _isConnecting = true;
      final userId = await injector<ConfigurationService>().getDeviceId();

      _reconnectTimer?.cancel();

      final apiKey = Environment.tvKey;
      final topicId = _device.topicId;
      final clientId = userId;

      final wsUrl = '${Environment.tvNotificationUrl}/api/notification?'
          'apiKey=$apiKey&topicID=$topicId&clientId=$clientId';

      log.info(
          '[CanvasNotificationService] Device ${_device.name} connecting to ${wsUrl.replaceAll(apiKey, '***')}');

      if (_receivePort == null) {
        _receivePort = ReceivePort();
        _receiveSub = _receivePort!.listen(_handleIsolateMessage);
        _isolateReadyCompleter = Completer<void>();
        _isolate = await Isolate.spawn(
          canvasNotificationIsolateEntry,
          _receivePort!.sendPort,
        );
      }

      // Wait for isolate to send back its SendPort.
      if (_isolateSendPort == null) {
        final completer = _isolateReadyCompleter;
        if (completer != null && !completer.isCompleted) {
          await completer.future;
        }
      }

      final control = CanvasNotificationControlMessage(
        type: CanvasNotificationMainToIsolateType.connect,
        data: CanvasNotificationConnectData(wsUrl: wsUrl),
      );
      _isolateSendPort?.send(control.toJson());

      // We don't block waiting for a connected event here; connectivity
      // will be tracked via messages from the isolate.
      return true;
    } catch (e) {
      _lastError = e.toString();
      _scheduleReconnect();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleIsolateMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final event = CanvasNotificationEventMessage.fromJson(
      Map<String, dynamic>.from(message),
    );

    if (event.type == CanvasNotificationIsolateToMainType.isolateReady) {
      final data = event.data;
      if (data is! CanvasNotificationIsolateReadyData) {
        return;
      }
      _isolateSendPort = data.sendPort;
      _isolateReadyCompleter ??= Completer<void>();
      if (!(_isolateReadyCompleter?.isCompleted ?? true)) {
        _isolateReadyCompleter!.complete();
      }
      return;
    }

    if (event.type == CanvasNotificationIsolateToMainType.notification) {
      final data = event.data;
      if (data is! CanvasNotificationNotificationData) {
        return;
      }
      try {
        _notificationController.add(data.notification);
      } catch (e, stackTrace) {
        log.info(
          '[CanvasNotificationService] Error parsing notification in main isolate: $e\n$stackTrace',
        );
      }
      return;
    }

    if (event.type == CanvasNotificationIsolateToMainType.connected) {
      _isConnected = true;
      _lastError = null;
      _reconnectTimer?.cancel();
      return;
    }

    if (event.type == CanvasNotificationIsolateToMainType.disconnected) {
      _isConnected = false;
      _scheduleReconnect();
      return;
    }

    if (event.type == CanvasNotificationIsolateToMainType.error) {
      _lastError = event.error;
      log.info(
        '[CanvasNotificationService] WebSocket error from isolate: ${event.error}',
      );
      _handleDisconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    log.info(
        '[CanvasNotificationService] Device ${_device.name} scheduling reconnect');
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      log.info(
          '[CanvasNotificationService] Device ${_device.name} attempting to reconnect to topic ${_device.topicId}');
      if (_reconnectTimer?.isActive ?? false) {
        await connect();
      }
    });
  }

  Future<void> disconnect() async {
    final control = CanvasNotificationControlMessage(
      type: CanvasNotificationMainToIsolateType.disconnect,
    );
    _isolateSendPort?.send(control.toJson());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _reconnectTimer?.cancel();
    _isConnected = false;
    await _receiveSub?.cancel();
    _receiveSub = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isolateReadyCompleter = null;
    log.info(
        '[CanvasNotificationService] Device ${_device.name} called disconnect');
  }

  bool get isConnected => _isConnected;

  String? get lastError => _lastError;
}
