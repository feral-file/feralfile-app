/// Message keys for commands sent from main to isolate.
class CanvasNotificationMainToIsolateType {
  CanvasNotificationMainToIsolateType._();

  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String dispose = 'dispose';
}

/// Base class for all control data types sent from main to isolate.
///
/// This represents data payloads for commands such as `connect`,
/// `disconnect`, `dispose`, etc.
abstract class CanvasNotificationControlData {
  const CanvasNotificationControlData();

  Map<String, dynamic> toJson();
}

/// Control data for the `connect` message.
class CanvasNotificationConnectData extends CanvasNotificationControlData {
  const CanvasNotificationConnectData({
    required this.wsUrl,
  });

  final String wsUrl;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'wsUrl': wsUrl,
      };

  factory CanvasNotificationConnectData.fromJson(
    Map<String, dynamic> json,
  ) {
    return CanvasNotificationConnectData(
      wsUrl: json['wsUrl'] as String? ?? '',
    );
  }
}

/// Control message sent from the main isolate to the notification isolate.
///
/// This class carries a [type] and an optional strongly-typed [data] object.
class CanvasNotificationControlMessage {
  CanvasNotificationControlMessage({
    required this.type,
    this.data,
  });

  final String type;
  final CanvasNotificationControlData? data;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        if (data != null) 'data': data!.toJson(),
      };

  factory CanvasNotificationControlMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    final type = json['type'] as String? ?? '';
    CanvasNotificationControlData? data;

    final rawData = json['data'];
    if (rawData is Map<String, dynamic> &&
        type == CanvasNotificationMainToIsolateType.connect) {
      data = CanvasNotificationConnectData.fromJson(rawData);
    }

    return CanvasNotificationControlMessage(
      type: type,
      data: data,
    );
  }
}
