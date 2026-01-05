import 'dart:isolate';

import 'package:autonomy_flutter/model/canvas_notification.dart';

/// Message keys for events sent from isolate back to main.
class CanvasNotificationIsolateToMainType {
  CanvasNotificationIsolateToMainType._();

  static const String isolateReady = 'isolateReady';
  static const String connected = 'connected';
  static const String disconnected = 'disconnected';
  static const String error = 'error';
  static const String notification = 'notification';
}

/// Base class for all event data types sent from isolate to main.
abstract class CanvasNotificationEventData {
  const CanvasNotificationEventData();

  Map<String, dynamic> toJson();
}

/// Event data for the `isolateReady` message, carrying back the [SendPort].
class CanvasNotificationIsolateReadyData extends CanvasNotificationEventData {
  const CanvasNotificationIsolateReadyData(this.sendPort);

  final SendPort sendPort;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'sendPort': sendPort,
      };

  factory CanvasNotificationIsolateReadyData.fromJson(
    Map<String, dynamic> json,
  ) {
    return CanvasNotificationIsolateReadyData(
      json['sendPort'] as SendPort,
    );
  }
}

/// Event data for notification messages, wrapping a [NotificationRelayerMessage].
class CanvasNotificationNotificationData extends CanvasNotificationEventData {
  const CanvasNotificationNotificationData(this.notification);

  final NotificationRelayerMessage notification;

  @override
  Map<String, dynamic> toJson() => notification.toJson();

  factory CanvasNotificationNotificationData.fromJson(
    Map<String, dynamic> json,
  ) {
    return CanvasNotificationNotificationData(
      NotificationRelayerMessage.fromJson(
        Map<String, dynamic>.from(json),
      ),
    );
  }
}

/// Event message sent from the notification isolate back to the main isolate.
class CanvasNotificationEventMessage {
  CanvasNotificationEventMessage({
    required this.type,
    this.data,
    this.error,
  });

  final String type;
  final CanvasNotificationEventData? data;
  final String? error;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        if (data != null) 'data': data!.toJson(),
        if (error != null) 'error': error,
      };

  factory CanvasNotificationEventMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final type = json['type'] as String? ?? '';

    CanvasNotificationEventData? data;
    final rawData = json['data'];
    if (rawData is Map<String, dynamic>) {
      if (type == CanvasNotificationIsolateToMainType.notification) {
        data = CanvasNotificationNotificationData.fromJson(rawData);
      } else if (type == CanvasNotificationIsolateToMainType.isolateReady) {
        data = CanvasNotificationIsolateReadyData.fromJson(rawData);
      }
    }

    return CanvasNotificationEventMessage(
      type: type,
      data: data,
      error: json['error'] as String?,
    );
  }

  /// Helper for converting from a [NotificationRelayerMessage].
  factory CanvasNotificationEventMessage.fromRelayer(
    NotificationRelayerMessage notification,
  ) {
    return CanvasNotificationEventMessage(
      type: CanvasNotificationIsolateToMainType.notification,
      data: CanvasNotificationNotificationData(notification),
    );
  }
}
