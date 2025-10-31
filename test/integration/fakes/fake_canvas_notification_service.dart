import 'dart:async';

import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/service/canvas_notification_service.dart';

class FakeCanvasNotificationService extends CanvasNotificationService {
  FakeCanvasNotificationService(BaseDevice device)
      : _controller = StreamController<NotificationRelayerMessage>.broadcast(),
        super(device);

  final StreamController<NotificationRelayerMessage> _controller;
  bool _connected = false;

  void emit(NotificationRelayerMessage message) => _controller.add(message);

  @override
  Stream<NotificationRelayerMessage> get notificationStream =>
      _controller.stream;

  @override
  Future<bool> connect() async {
    _connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _controller.close();
  }

  @override
  bool get isConnected => _connected;
}
