import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';

import './mock_check_casting_status_reply.dart';
import './mock_device_status.dart';

/// Utilities to create mock NotificationRelayerMessage instances for tests.
///
/// Covers all RelayerMessageType values and common RelayerNotificationType cases.
class MockNotificationRelayerMessage {
  /// Create a generic notification message with a specific notification type
  /// and custom message payload.
  static NotificationRelayerMessage notification({
    required RelayerNotificationType notificationType,
    Map<String, dynamic> message = const <String, dynamic>{},
    DateTime? timestamp,
  }) {
    return NotificationRelayerMessage(
      type: RelayerMessageType.notification,
      message: message,
      notificationType: notificationType,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// player_status notification
  static NotificationRelayerMessage status({
    CheckCastingStatusReply? reply,
    DateTime? timestamp,
  }) {
    final r = reply ?? MockCheckCastingStatusReply.basic();
    return notification(
      notificationType: RelayerNotificationType.status,
      message: r.toJson(),
      timestamp: timestamp,
    );
  }

  /// device_status notification
  static NotificationRelayerMessage deviceStatus({
    DeviceStatus? status,
    DateTime? timestamp,
  }) {
    final s = status ?? MockDeviceStatusData.basic();
    return notification(
      notificationType: RelayerNotificationType.deviceStatus,
      message: s.toJson(),
      timestamp: timestamp,
    );
  }

  /// connection notification
  static NotificationRelayerMessage connection({
    bool isConnected = true,
    DateTime? timestamp,
  }) {
    return notification(
      notificationType: RelayerNotificationType.connection,
      message: <String, dynamic>{'isConnected': isConnected},
      timestamp: timestamp,
    );
  }

  /// Create a mock RelayerMessage of type RPC in the format compatible with
  /// NotificationRelayerMessage.fromJson. Even though RPC is not a
  /// NotificationRelayerMessage semantically, tests may still want a JSON map
  /// that can be parsed via fromJson for negative/edge cases.
  static Map<String, dynamic> rpcJson({
    Map<String, dynamic> payload = const <String, dynamic>{'method': 'noop'},
    DateTime? timestamp,
  }) {
    return <String, dynamic>{
      'type': RelayerMessageType.rpc.value,
      'message': payload,
      // For rpc we keep notification_type to a valid value to satisfy parser
      // in NotificationRelayerMessage.fromJson for edge-case tests
      'notification_type': RelayerNotificationType.status.value,
      'timestamp': (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  /// Convenience: build JSON map for a notification entry that can be parsed
  /// by NotificationRelayerMessage.fromJson.
  static Map<String, dynamic> toJson(NotificationRelayerMessage message) {
    return <String, dynamic>{
      'type': message.type.value,
      'message': message.message,
      'notification_type': message.notificationType.value,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
    };
  }
}
