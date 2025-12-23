import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/canvas_notification.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/canvas_notification_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/now_displaying_manager.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

class CanvasNotificationManager {
  factory CanvasNotificationManager() => _instance;

  CanvasNotificationManager._internal();

  // single ton
  static final CanvasNotificationManager _instance =
      CanvasNotificationManager._internal();

  // Map to hold connected CanvasNotificationService instances
  final Map<String, CanvasNotificationService> _services = {};

  // Map to hold subscriptions for each service's stream
  final Map<String, StreamSubscription<RelayerMessage>> _subscriptions = {};

  // Map to hold retry timers

  // Map to hold current processing messages for each device, grouped by notification type
  final Map<String,
          Map<RelayerNotificationType, Pair<BaseDevice, RelayerMessage>>>
      _processingMessages = {};

  // Map to hold next messages for each device, grouped by notification type
  final Map<String,
          Map<RelayerNotificationType, Pair<BaseDevice, RelayerMessage>>>
      _nextMessages = {};

  // Flag to track if processing is in progress for each device and notification type
  final Map<String, Map<RelayerNotificationType, bool>> _isProcessing = {};

  // Stream controller for combined notifications
  final _combinedNotificationController =
      StreamController<Pair<BaseDevice, RelayerMessage>>.broadcast();

  // Combined notification stream
  Stream<Pair<BaseDevice, RelayerMessage>> get combinedNotificationStream =>
      _combinedNotificationController.stream;

  StreamSubscription<FGBGType>? _fgbgSubscription;

  static const _maxRetryAttempts = 10;
  static const _retryDelay = Duration(seconds: 5);

  // start function: connect to all devices
  Future<void> start() async {
    await _reconnectAll();

    // Listen to app lifecycle changes
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);

    combinedNotificationStream.listen(
      (Pair<BaseDevice, RelayerMessage> pair) {
        final device = pair.first;
        final deviceId = device.deviceId;
        final notification = pair.second;

        // Initialize maps for this device if not exists
        _processingMessages.putIfAbsent(deviceId, () => {});
        _nextMessages.putIfAbsent(deviceId, () => {});
        _isProcessing.putIfAbsent(deviceId, () => {});

        if (notification is NotificationRelayerMessage) {
          _handleNotification(device, notification);
        }
      },
      onError: (Object error) {
        log.info('Error in combined notification stream: $error');
      },
      onDone: () {
        log.info('Combined notification stream done');
      },
    );
  }

  void _handleNotification(
      BaseDevice device, NotificationRelayerMessage notification) {
    {
      final deviceId = device.deviceId;
      final notificationType = notification.notificationType;

      // If there's a message being processed of the same type, check its timestamp
      if (_isProcessing[deviceId]?[notificationType] == true) {
        final processingMessage =
            _processingMessages[deviceId]![notificationType];
        final processingNotification =
            processingMessage?.second as NotificationRelayerMessage?;
        if (processingNotification != null &&
            notification.timestamp.isBefore(processingNotification.timestamp)) {
          log.info(
              'Skipping older message for device $deviceId and type $notificationType: ${notification.timestamp} < ${processingNotification.timestamp}');
          return;
        }
      }

      // Check if we have a next message of the same type
      final nextMessage = _nextMessages[deviceId]![notificationType];
      if (nextMessage != null) {
        // If new message is older than next message, skip it
        final nextNotification =
            nextMessage.second as NotificationRelayerMessage?;
        if (nextNotification != null &&
            notification.timestamp.isBefore(nextNotification.timestamp)) {
          log.info(
              'Skipping older message for device $deviceId and type $notificationType: ${notification.timestamp} < ${nextNotification.timestamp}');
          return;
        }
      }

      // Update next message for this type
      _nextMessages[deviceId]![notificationType] = Pair(device, notification);

      // Process next notification of this type if not already processing
      if (_isProcessing[deviceId]?[notificationType] != true) {
        _processNextNotification(deviceId, notificationType);
      }
    }
  }

  void _handleForeBackground(FGBGType event) {
    switch (event) {
      case FGBGType.foreground:
        _reconnectAll();
      case FGBGType.background:
        _disconnectAll();
    }
  }

  Future<void> _reconnectAll() async {
    final devices = [
      if (BluetoothDeviceManager().castingBluetoothDevice != null)
        BluetoothDeviceManager().castingBluetoothDevice!
    ];
    for (final device in devices) {
      try {
        await connect(device);
      } catch (e) {
        log.warning('Error reconnecting to device ${device.deviceId}: $e');
      }
    }
  }

  // Connect to a specific device
  Future<void> connect(BaseDevice device) async {
    var service = _services[device.deviceId];

    if (service == null) {
      final newService = CanvasNotificationService(device);
      _services[device.deviceId] = newService;
      // Subscribe to the new service's stream and add to the combined stream
      _subscriptions[device.deviceId] = newService.notificationStream.listen(
        (notification) {
          _combinedNotificationController.add(
            Pair<BaseDevice, RelayerMessage>(
              device,
              notification,
            ),
          );
        },
        onError: (Object error) {
          // Handle error from individual service stream if needed
          log.warning('Error from device ${device.deviceId}: $error');
        },
        onDone: () {
          // Handle individual service stream completion if needed
          log.info('Device ${device.deviceId} stream done');
        },
      );
      service = newService;
    }
    if (service.isConnected) {
      return;
    }
    try {
      final res = await service.connect();
      if (!res) {
        unawaited(NowDisplayingManager().updateDisplayingNow());
      }
    } catch (e) {
      log.warning('Error connecting to device ${device.deviceId}: $e');
      // update Now Displaying as when connect failed.
      unawaited(NowDisplayingManager().updateDisplayingNow());
    }
  }

  // Disconnect from a specific device
  Future<void> disconnect(String deviceId) async {
    // Clear messages for this device
    _processingMessages.remove(deviceId);
    _nextMessages.remove(deviceId);
    _isProcessing.remove(deviceId);

    final service = _services.remove(deviceId);
    if (service != null) {
      await service.disconnect();
      // Cancel the subscription for this device
      await _subscriptions.remove(deviceId)?.cancel();
    }
  }

  // Disconnect from all devices
  Future<void> disconnectAll() async {
    await _disconnectAll();
  }

  Future<void> _disconnectAll() async {
    // Clear all messages
    _processingMessages.clear();
    _nextMessages.clear();
    _isProcessing.clear();

    final futures =
        _services.values.map((service) => service.disconnect()).toList();
    _services.clear();
    // Cancel all subscriptions
    await Future.wait(_subscriptions.values.map((sub) => sub.cancel()));
    _subscriptions.clear();
    await Future.wait(futures);
  }

  // Get notification stream for a specific device
  Stream<RelayerMessage>? getNotificationStream(String deviceId) {
    return _services[deviceId]?.notificationStream;
  }

  // on message (This method seems redundant now with the combined stream approach, consider removing)
  // void onMessage(String deviceId, NotificationRelayerMessage notification) {}

  // Dispose method to clean up
  void dispose() {
    _fgbgSubscription?.cancel();
    _disconnectAll();
    _combinedNotificationController.close();

    // Clear all messages and processing flags
    _processingMessages.clear();
    _nextMessages.clear();
    _isProcessing.clear();
  }

  Future<void> _processNextNotification(
      String deviceId, RelayerNotificationType notificationType) async {
    if (_nextMessages[deviceId]?[notificationType] == null) {
      _isProcessing[deviceId]![notificationType] = false;
      _processingMessages[deviceId]?.remove(notificationType);

      // Clean up empty maps
      if (_processingMessages[deviceId]?.isEmpty ?? false) {
        _processingMessages.remove(deviceId);
      }
      if (_isProcessing[deviceId]?.isEmpty ?? false) {
        _isProcessing.remove(deviceId);
      }
      return;
    }

    _isProcessing[deviceId]![notificationType] = true;
    final pair = _nextMessages[deviceId]!.remove(notificationType)!;
    _processingMessages[deviceId]![notificationType] = pair;

    final device = pair.first;
    final notification = pair.second;

    try {
      // Handle the notification based on its type
      switch (notificationType) {
        case RelayerNotificationType.status:
          final message = notification.message;
          final status = CheckCastingStatusReply.fromJson(message);
          injector<CanvasDeviceBloc>().add(
            CanvasDeviceUpdateCastingStatusEvent(
              device,
              status,
            ),
          );

        case RelayerNotificationType.deviceStatus:
          final message = notification.message;
          final deviceStatus = DeviceStatus.fromJson(message);
          BluetoothDeviceManager().castingDeviceStatus.value = deviceStatus;

        case RelayerNotificationType.connection:
          final message = notification.message;
          final isConnected = message['isConnected'] as bool;
          injector<CanvasDeviceBloc>().add(
            CanvasDeviceUpdateConnectionEvent(device, isConnected),
          );
      }
    } catch (e, stackTrace) {
      log.warning(
        'Error processing notification for device $deviceId and type $notificationType: $e\nStack trace: $stackTrace',
      );
    } finally {
      // Remove processed message
      _processingMessages[deviceId]?.remove(notificationType);
      // Process next notification of this type if available
      _processNextNotification(deviceId, notificationType);
    }
  }

// You might want methods to list connected devices, check connection status, etc.
}
