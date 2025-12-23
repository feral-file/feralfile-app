import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/ff1_relayer_notification/ff1_relayer_main_to_isolate.dart';
import 'package:autonomy_flutter/model/ff1_relayer_notification/ff1_relayer_isolate_to_main.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Entry point for the canvas notification isolate.
///
/// [message] is expected to be a [SendPort] created by the main isolate.
/// The isolate will:
/// - send back its own [SendPort] wrapped in a `{type: isolateReady, sendPort}` map
/// - wait for a `{type: connect, wsUrl: ...}` control message
/// - manage WebSocket connection and reconnection
/// - decode JSON and construct [NotificationRelayerMessage] in the isolate
/// - send trimmed JSON map to the main isolate as `{type: notification, data: ...}`
void canvasNotificationIsolateEntry(dynamic message) {
  if (message is! SendPort) {
    return;
  }

  final mainSendPort = message;

  final controlPort = ReceivePort();
  final readyEvent = CanvasNotificationEventMessage(
    type: CanvasNotificationIsolateToMainType.isolateReady,
    data: CanvasNotificationIsolateReadyData(controlPort.sendPort),
  );
  mainSendPort.send(readyEvent.toJson());

  WebSocketChannel? channel;
  StreamSubscription<dynamic>? channelSub;
  Timer? reconnectTimer;

  var wsUrl = '';
  var isDisposed = false;
  var isConnecting = false;

  Future<void> closeChannel() async {
    await channelSub?.cancel();
    channelSub = null;
    await channel?.sink.close();
    channel = null;
  }

  Future<void> connect() async {
    if (isDisposed || isConnecting || wsUrl.isEmpty) {
      return;
    }
    isConnecting = true;

    try {
      final uri = Uri.parse(wsUrl);
      channel = WebSocketChannel.connect(uri);

      log.info(
        '[CanvasNotificationIsolate] Connecting to ${uri.toString()}',
      );

      channelSub = channel!.stream.listen(
        (dynamic rawMessage) {
          try {
            if (rawMessage is! String) {
              return;
            }

            final decoded = jsonDecode(rawMessage) as Map<String, dynamic>;
            final notification = NotificationRelayerMessage.fromJson(decoded);
            final event =
                CanvasNotificationEventMessage.fromRelayer(notification);
            mainSendPort.send(event.toJson());
          } catch (e, stackTrace) {
            log.info(
              '[CanvasNotificationIsolate] Error parsing notification: $e\n$stackTrace',
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          final errorEvent = CanvasNotificationEventMessage(
            type: CanvasNotificationIsolateToMainType.error,
            error: error.toString(),
          );
          mainSendPort.send(errorEvent.toJson());
          log.info(
            '[CanvasNotificationIsolate] WebSocket error: $error\n$stackTrace',
          );
          unawaited(closeChannel());
          final disconnectedEvent = CanvasNotificationEventMessage(
            type: CanvasNotificationIsolateToMainType.disconnected,
          );
          mainSendPort.send(disconnectedEvent.toJson());
        },
        onDone: () {
          final event = CanvasNotificationEventMessage(
            type: CanvasNotificationIsolateToMainType.disconnected,
          );
          mainSendPort.send(event.toJson());
        },
      );

      final event = CanvasNotificationEventMessage(
        type: CanvasNotificationIsolateToMainType.connected,
      );
      mainSendPort.send(event.toJson());
    } catch (e, stackTrace) {
      final errorEvent = CanvasNotificationEventMessage(
        type: CanvasNotificationIsolateToMainType.error,
        error: e.toString(),
      );
      mainSendPort.send(errorEvent.toJson());
      log.info(
        '[CanvasNotificationIsolate] Failed to connect: $e\n$stackTrace',
      );
      await closeChannel();
    } finally {
      isConnecting = false;
    }
  }

  controlPort.listen((dynamic rawMessage) async {
    if (rawMessage is! Map) {
      return;
    }

    final control = CanvasNotificationControlMessage.fromJson(
      Map<String, dynamic>.from(rawMessage),
    );
    final type = control.type;
    if (type.isEmpty) {
      return;
    }

    if (type == CanvasNotificationMainToIsolateType.connect) {
      final connectData = control.data is CanvasNotificationConnectData
          ? control.data! as CanvasNotificationConnectData
          : null;
      wsUrl = connectData?.wsUrl ?? '';
      reconnectTimer?.cancel();
      await closeChannel();
      unawaited(connect());
      return;
    }

    if (type == CanvasNotificationMainToIsolateType.disconnect) {
      isDisposed = true;
      reconnectTimer?.cancel();
      await closeChannel();
      final event = CanvasNotificationEventMessage(
        type: CanvasNotificationIsolateToMainType.disconnected,
      );
      mainSendPort.send(event.toJson());
      return;
    }

    if (type == CanvasNotificationMainToIsolateType.dispose) {
      isDisposed = true;
      reconnectTimer?.cancel();
      await closeChannel();
      controlPort.close();
    }
  });
}
