enum RelayerMessageType {
  notification,
  rpc;

  String get value {
    switch (this) {
      case RelayerMessageType.notification:
        return 'notification';
      case RelayerMessageType.rpc:
        return 'RPC';
    }
  }

  static RelayerMessageType fromString(String value) {
    switch (value) {
      case 'notification':
        return RelayerMessageType.notification;
      case 'RPC':
        return RelayerMessageType.rpc;
      default:
        throw ArgumentError('Unknown RelayerMessageType: $value');
    }
  }
}

enum RelayerNotificationType {
  status,
  deviceStatus,
  connection;

  String get value {
    switch (this) {
      case RelayerNotificationType.status:
        return 'player_status';
      case RelayerNotificationType.deviceStatus:
        return 'device_status';
      case RelayerNotificationType.connection:
        return 'connection';
    }
  }

  static RelayerNotificationType fromString(String value) {
    switch (value) {
      case 'player_status':
        return RelayerNotificationType.status;
      case 'device_status':
        return RelayerNotificationType.deviceStatus;
      case 'connection':
        return RelayerNotificationType.connection;
      default:
        throw ArgumentError('Unknown RelayerNotificationType: $value');
    }
  }
}

class RelayerMessage {
  RelayerMessage({
    required this.type,
    required this.message,
  });

  final RelayerMessageType type;
  final Map<String, dynamic> message;
}

class NotificationRelayerMessage extends RelayerMessage {
  NotificationRelayerMessage({
    required super.type,
    required super.message,
    required this.notificationType,
    required this.timestamp,
  });

  factory NotificationRelayerMessage.fromJson(Map<String, dynamic> json) {
    return NotificationRelayerMessage(
      type: RelayerMessageType.fromString(json['type'] as String),
      message: json['message'] as Map<String, dynamic>,
      notificationType: RelayerNotificationType.fromString(
          json['notification_type'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int,
      ),
    );
  }

  final RelayerNotificationType notificationType;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'message': message,
      'notification_type': notificationType.value,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
