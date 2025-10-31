import 'package:autonomy_flutter/model/canvas_notification.dart';

/// Mock data factory for NotificationRelayerMessage objects
class MockNotificationRelayerMessage {
  /// Create a basic NotificationRelayerMessage object
  static NotificationRelayerMessage create({
    RelayerMessageType type = RelayerMessageType.notification,
    RelayerNotificationType notificationType = RelayerNotificationType.status,
    Map<String, dynamic>? message,
    DateTime? timestamp,
  }) {
    return NotificationRelayerMessage(
      type: type,
      message: message ??
          {
            'ok': true,
            'index': 0,
            'isPaused': false,
          },
      notificationType: notificationType,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Create a status notification
  static NotificationRelayerMessage createStatusNotification({
    int? index,
    bool? isPaused,
    DateTime? timestamp,
  }) {
    return NotificationRelayerMessage(
      type: RelayerMessageType.notification,
      message: {
        'ok': true,
        if (index != null) 'index': index,
        if (isPaused != null) 'isPaused': isPaused,
      },
      notificationType: RelayerNotificationType.status,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Create a device status notification
  static NotificationRelayerMessage createDeviceStatusNotification({
    Map<String, dynamic>? deviceStatusData,
    DateTime? timestamp,
  }) {
    return NotificationRelayerMessage(
      type: RelayerMessageType.notification,
      message: deviceStatusData ??
          {
            'screenRotation': 'landscape',
            'connectedWifi': 'Test WiFi',
            'installedVersion': '1.0.0',
            'latestVersion': '1.0.0',
          },
      notificationType: RelayerNotificationType.deviceStatus,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Create a connection notification
  static NotificationRelayerMessage createConnectionNotification({
    bool isConnected = true,
    DateTime? timestamp,
  }) {
    return NotificationRelayerMessage(
      type: RelayerMessageType.notification,
      message: {
        'isConnected': isConnected,
      },
      notificationType: RelayerNotificationType.connection,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Create list of notifications
  static List<NotificationRelayerMessage> createList({
    int count = 3,
    RelayerNotificationType notificationType = RelayerNotificationType.status,
  }) {
    return List.generate(count, (index) {
      return create(
        notificationType: notificationType,
        timestamp: DateTime.now().add(Duration(seconds: index)),
      );
    });
  }

  /// Create notification with older timestamp
  static NotificationRelayerMessage createWithOlderTimestamp({
    Duration offset = const Duration(seconds: -10),
  }) {
    return create(timestamp: DateTime.now().add(offset));
  }

  /// Create notification with newer timestamp
  static NotificationRelayerMessage createWithNewerTimestamp({
    Duration offset = const Duration(seconds: 10),
  }) {
    return create(timestamp: DateTime.now().add(offset));
  }

  /// Create empty notification
  static NotificationRelayerMessage createEmpty({
    RelayerNotificationType notificationType = RelayerNotificationType.status,
  }) {
    return NotificationRelayerMessage(
      type: RelayerMessageType.notification,
      message: {},
      notificationType: notificationType,
      timestamp: DateTime.now(),
    );
  }

  /// Create notification from JSON
  static NotificationRelayerMessage fromJson(Map<String, dynamic> json) {
    return NotificationRelayerMessage.fromJson(json);
  }
}
