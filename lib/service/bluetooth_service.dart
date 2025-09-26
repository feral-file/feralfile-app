import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/error/bluetooth_error.dart';
import 'package:autonomy_flutter/model/error/bluetooth_response_error.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_state.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/bluetooth_notification_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/bluetooth_manager.dart';
import 'package:autonomy_flutter/util/byte_builder_ext.dart';
import 'package:autonomy_flutter/util/exception_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/timezone.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry/sentry.dart';

enum BluetoothCommand {
  sendWifiCredentials,
  scanWifi,
  keepWifi,
  factoryReset,
  sendLog,
  setTimezone;

  String get name {
    switch (this) {
      case BluetoothCommand.sendWifiCredentials:
        return 'connect_wifi';
      case BluetoothCommand.scanWifi:
        return 'scan_wifi';
      case BluetoothCommand.keepWifi:
        return 'keep_wifi';
      case BluetoothCommand.factoryReset:
        return 'factory_reset';
      case BluetoothCommand.sendLog:
        return 'send_log';
      case BluetoothCommand.setTimezone:
        return 'set_time';
    }
  }

  NotificationCallback _scanWifiCallback(
    Completer<ScanWifiResponse> completer,
  ) {
    return (data) {
      if (data.errorCode != 0) {
        log.warning('Error scanning wifi: ${data.errorCode}');
      }
      final listSsid = data.data;
      completer.complete(ScanWifiResponse(result: listSsid));
    };
  }

  NotificationCallback _keepWifiCallback(
    Completer<KeepWifiResponse> completer,
  ) {
    return (data) {
      if (data.errorCode != 0) {
        log.warning('Error keeping wifi: ${data.errorCode}');
        final error = FFBluetoothResponseError.fromErrorCode(data.errorCode);
        completer.completeError(
          error,
        );
      }
      final topicId = data.data[0];
      completer.complete(KeepWifiResponse(topicId: topicId));
    };
  }

  NotificationCallback _sendWifiCredentialsCallback(
    Completer<SendWifiCredentialResponse> completer,
  ) {
    return (data) {
      if (data.errorCode != 0) {
        log.warning('Error sending wifi credentials: ${data.errorCode}');
        final error = FFBluetoothResponseError.fromErrorCode(data.errorCode);
        completer.completeError(
          error,
        );
        return;
      }
      final topicId = data.data[0];
      completer.complete(
        SendWifiCredentialResponse(
          topicId: topicId,
        ),
      );
    };
  }

  NotificationCallback _factoryResetCallback(
    Completer<FactoryResetResponse> completer,
  ) {
    return (data) {
      if (data.errorCode != 0) {
        log.warning('Error resetting factory: ${data.errorCode}');
        final error = FFBluetoothResponseError.fromErrorCode(data.errorCode);
        completer.completeError(
          error,
        );
      }
      completer.complete(FactoryResetResponse());
    };
  }

  NotificationCallback _sendLogCallback(
    Completer<SendLogResponse> completer,
  ) {
    return (data) {
      if (data.errorCode != 0) {
        log.warning('Error sending log: ${data.errorCode}');
        final error = FFBluetoothResponseError.fromErrorCode(data.errorCode);
        completer.completeError(
          error,
        );
      }
      completer.complete(SendLogResponse());
    };
  }

  // cb for setTimezone
  NotificationCallback _setTimezoneCallback(
    Completer<SetTimezoneReply> completer,
  ) {
    return (data) {
      completer.complete(SetTimezoneReply());
    };
  }

  Completer<BluetoothResponse> generateCompleter() {
    switch (this) {
      case BluetoothCommand.sendWifiCredentials:
        return Completer<SendWifiCredentialResponse>();
      case BluetoothCommand.scanWifi:
        return Completer<ScanWifiResponse>();
      case BluetoothCommand.keepWifi:
        return Completer<KeepWifiResponse>();
      case BluetoothCommand.factoryReset:
        return Completer<FactoryResetResponse>();
      case BluetoothCommand.sendLog:
        return Completer<SendLogResponse>();
      case BluetoothCommand.setTimezone:
        return Completer<SetTimezoneReply>();
    }
  }

  NotificationCallback notificationCallback(
    Completer<BluetoothResponse> completer,
  ) {
    switch (this) {
      case BluetoothCommand.sendWifiCredentials:
        return _sendWifiCredentialsCallback(
          completer as Completer<SendWifiCredentialResponse>,
        );
      case BluetoothCommand.scanWifi:
        return _scanWifiCallback(
          completer as Completer<ScanWifiResponse>,
        );
      case BluetoothCommand.keepWifi:
        return _keepWifiCallback(
          completer as Completer<KeepWifiResponse>,
        );
      case BluetoothCommand.factoryReset:
        return _factoryResetCallback(
          completer as Completer<FactoryResetResponse>,
        );
      case BluetoothCommand.sendLog:
        return _sendLogCallback(
          completer as Completer<SendLogResponse>,
        );
      case BluetoothCommand.setTimezone:
        return _setTimezoneCallback(
          completer as Completer<SetTimezoneReply>,
        );
    }
  }
}

class FFBluetoothService {
  FFBluetoothService();

  bool _listeningForAdapterState = false;

  void startListen() {
    log.info('Start listening to bluetooth events');
    FlutterBluePlus.events.onDiscoveredServices.listen((event) {
      log.info('Discovered services: $event');
    });
    FlutterBluePlus.events.onConnectionStateChanged.listen((event) async {
      final device = event.device;
      final state = event.connectionState;
      log.info(
        'Connection state update for ${device.remoteId.str}: ${state.name}',
      );
      if (state == BluetoothConnectionState.connected) {
        final hash = _connectCompleter?.hashCode;
        try {
          // add safe delay to ensure connection is stable
          await Future.delayed(const Duration(seconds: 1));
          await device.discoverCharacteristics();
          if (_connectCompleter?.isCompleted == false) {
            _connectCompleter?.complete();
          }
          _connectCompleter = null;
        } catch (e, s) {
          log.warning(
            '[onConnectionStateChanged] Failed to discover characteristics: $e',
          );
          unawaited(
            Sentry.captureException(
              '[onConnectionStateChanged] Failed to discover characteristics: $e',
              stackTrace: s,
            ),
          );
          log.info(
            '[onConnectionStateChanged] Disconnecting from device: ${device.remoteId.str} due to error $e',
          );
          await device.disconnect();
          if (hash == _connectCompleter?.hashCode) {
            if (_connectCompleter?.isCompleted == false) {
              _connectCompleter?.completeError(e);
            }
            _connectCompleter = null;
          }
        }
      } else if (state == BluetoothConnectionState.disconnected) {
        log.warning('Device disconnected reason: ${device.disconnectReason}');
        if (_connectCompleter?.isCompleted == false) {
          final exception = FFBluetoothDisconnectedError(
            disconnectReason: device.disconnectReason,
          );
          log.info(
            'Completing _connectCompleter with error: ${device.disconnectReason}',
          );
          _connectCompleter?.completeError(
            exception,
          );
        }
      }
    });

    FlutterBluePlus.events.onServicesReset.listen((event) {
      log.info('Services reset: $event');
      event.device.discoverCharacteristics();
    });
    FlutterBluePlus.events.onCharacteristicReceived.listen(
      (event) {
        final characteristic = event.characteristic;
        final device = event.device;
        final value = event.value;
        if (characteristic.isWifiConnectCharacteristic) {
          log.info(
            'WifiConnectCharacteristic receive data: ${value.join(', ')}',
          );
          BluetoothNotificationService().handleNotification(value, device);
        }
      },
      onError: (Object e) {
        log.warning('Error receiving characteristic: $e');
      },
    );
  }

  Future<void> init() async {
    FlutterBluePlus.logs.listen((event) {
      log.info('[FlutterBluePlus]: $event');
    });
    if (await Permission.bluetooth.isGranted ||
        BluetoothDeviceManager().castingBluetoothDevice != null) {
      await listenForAdapterState();
    }

    FlutterBluePlus.logs.listen((event) {
      log.info('[FlutterBluePlus]: $event');
    });
  }

  Future<void> listenForAdapterState() async {
    if (_listeningForAdapterState) {
      return;
    }
    _listeningForAdapterState = true;
    if (!(await FlutterBluePlus.isSupported)) {
      log.info('Bluetooth is not supported');
      injector<BluetoothConnectBloc>().add(
        BluetoothConnectEventUpdateBluetoothState(
          BluetoothAdapterState.unavailable,
        ),
      );
      return;
    }
    final stateNow = FlutterBluePlus.adapterStateNow;
    injector<BluetoothConnectBloc>()
        .add(BluetoothConnectEventUpdateBluetoothState(stateNow));
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState bluetoothState) {
      _bluetoothAdapterState = bluetoothState;
      injector<BluetoothConnectBloc>()
          .add(BluetoothConnectEventUpdateBluetoothState(bluetoothState));
    });
  }

  BluetoothAdapterState _bluetoothAdapterState = BluetoothAdapterState.unknown;

  bool get isBluetoothOn => _bluetoothAdapterState == BluetoothAdapterState.on;

  Future<BluetoothResponse> sendCommand({
    required BluetoothDevice device,
    required BluetoothCommand command,
    required Map<String, dynamic> request,
    Duration timeout = const Duration(seconds: 10),
    bool shouldShowError = true,
    bool shouldWaitForReply = true,
  }) async {
    log.info(
      '[sendCommand] Sending command: $command to device: ${device.remoteId.str}',
    );

    if (device.isDisconnected) {
      log.info('[sendCommand] Device is disconnected');
      unawaited(
        injector<NavigationService>().showCannotConnectToBluetoothDevice(
          device,
          'Device is disconnected',
        ),
      );
      throw Exception('Device is disconnected');
    }

    // Generate random 4 char replyId
    final replyId = String.fromCharCodes(
      List.generate(4, (_) => Random().nextInt(26) + 97),
    );

    final byteBuilder = _buildCommandMessage(command.name, request, replyId);

    final completer = command.generateCompleter();
    if (shouldWaitForReply) {
      final cb = command.notificationCallback(completer);
      BluetoothNotificationService().subscribe(replyId, cb);
      log.info(
        '[sendCommand] Subscribed to replyId: $replyId',
      );
    }
    try {
      final bytes = byteBuilder.takeBytes();

      final wifiChar = device.wifiConnectCharacteristic;
      if (wifiChar == null) {
        log.warning('Command characteristic not found');
        unawaited(Sentry.captureMessage('Command characteristic not found'));
        throw Exception('Command characteristic not found');
      }

      await wifiChar.writeWithRetry(bytes);

      // Wait for reply with timeout
      final res = shouldWaitForReply
          ? await completer.future.timeout(
              timeout,
              onTimeout: () {
                Sentry.captureMessage(
                  '[sendCommand] Timeout waiting for reply: $replyId',
                );
                throw TimeoutException('Timeout  waiting for reply $replyId');
              },
            )
          : const EmptyBluetoothResponse();
      return res;
    } catch (e, s) {
      // BluetoothNotificationService().unsubscribe(replyId, cb);
      unawaited(Sentry.captureException(e, stackTrace: s));
      log.info(
        '[sendCommand] Error sending command $command(replyId is $replyId): $e',
      );
      rethrow;
    }
  }

  BytesBuilder _buildCommandMessage(
    String command,
    Map<String, dynamic> request,
    String replyId,
  ) {
    final commandBytes = ascii.encode(command);
    final replyIdBytes = ascii.encode(replyId);

    // Prepare the BytesBuilder to collect all data
    final builder = BytesBuilder()
      ..writeVarint(commandBytes.length)
      ..add(commandBytes)
      ..writeVarint(replyIdBytes.length)
      ..add(replyIdBytes);

    // Loop through the request map and handle each key-value pair
    for (final entry in request.entries) {
      final value = entry.value;

      final valueBytes = ascii.encode(value.toString());

      builder
        ..writeVarint(valueBytes.length)
        ..add(valueBytes);
    }

    return builder;
  }

  Future<void> setTimezone(BluetoothDevice device) async {
    final timezone = await TimezoneHelper.getTimeZone();
    log.info('[setTimezone] timezone: $timezone');
    final res = await sendCommand(
      device: device,
      command: BluetoothCommand.setTimezone,
      request: SetTimezoneRequest(timezone: timezone).toJson(),
      timeout: const Duration(seconds: 5),
      shouldWaitForReply: false,
    );
    log.info(
      '[setTimezone] set timezone to $timezone for device: ${device.remoteId.str} with res: $res',
    );
  }

  Future<List<String>> scanWifi(BluetoothDevice device) async {
    const request = ScanWifiRequest();
    final res = await sendCommand(
      device: device,
      command: BluetoothCommand.scanWifi,
      request: request.toJson(),
    );

    if (res is! ScanWifiResponse) {
      log.warning('Failed to scan Wi-Fi');
      throw Exception('Failed to scan Wi-Fi');
    }

    final scanWifiResponse = res;
    final wifiList = scanWifiResponse.result;
    return wifiList;
  }

  Future<String> keepWifi(BluetoothDevice device) async {
    final request = KeepWifiRequest();
    final res = await sendCommand(
      device: device,
      command: BluetoothCommand.keepWifi,
      request: request.toJson(),
    );

    if (res is! KeepWifiResponse) {
      log.warning('Failed to keep Wi-Fi');
      throw Exception('Failed to keep Wi-Fi');
    }

    final keepWifiResponse = res;
    return keepWifiResponse.topicId;
  }

  Future<String?> sendWifiCredentials({
    required BluetoothDevice device,
    required String ssid,
    required String password,
  }) async {
    if (device.isDisconnected) {
      log.info('[sendWifi] Device is disconnected');
      unawaited(
        injector<NavigationService>().showCannotConnectToBluetoothDevice(
          device,
          'Device is disconnected',
        ),
      );
      return null;
    }

    final res = await sendCommand(
      device: device,
      command: BluetoothCommand.sendWifiCredentials,
      request: SendWifiCredentialRequest(
        ssid: ssid,
        password: password,
      ).toJson(),
      timeout: const Duration(seconds: 30),
    );

    if (res is! SendWifiCredentialResponse) {
      log.warning('Failed to send Wi-Fi credentials');
      unawaited(Sentry.captureMessage('Failed to send Wi-Fi credentials'));
      return null;
    }

    final sendWifiCredentialResponse = res;

    log.info(
      '[sendWifi] sendWifiCredentials success, topicId: ${sendWifiCredentialResponse.topicId}',
    );

    // Update device with topicId
    return sendWifiCredentialResponse.topicId;
  }

  // completer for connectToDevice
  Completer<void>? _connectCompleter;

  // completer for multi call connectToDevice
  Completer<void>? _multiConnectCompleter;

  Future<void> scanAndConnect(
    FFBluetoothDevice device, {
    bool shouldShowError = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    FFBluetoothDevice blDevice = device;
    if (device.remoteId.str.isEmpty) {
      final result = await scanForName(name: device.deviceId);
      if (result == null) {
        log.warning('FF1 not found during scan');
        throw Exception('FF1 not found during scan');
      } else {
        final newFF1 = device.copyWith(remoteID: result.remoteId.str);
        await BluetoothDeviceManager().addDevice(newFF1);
        blDevice = newFF1;
      }
    }

    if (blDevice.isDisconnected) {
      await connectToDevice(
        blDevice,
        shouldShowError: shouldShowError,
        timeout: timeout,
      );
    }
  }

  Future<void> connectToDevice(
    BluetoothDevice device, {
    bool shouldShowError = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_multiConnectCompleter?.isCompleted == false) {
      log.info(
        '''
[connectToDevice] Already connecting to device: ${device.remoteId.str}''',
      );
      return _multiConnectCompleter?.future;
    }

    _multiConnectCompleter = Completer<void>();

    _connectDevice(device, shouldShowError: shouldShowError, timeout: timeout)
        .then((_) {
      log.info('Connected to device: ${device.remoteId.str}');

      _multiConnectCompleter?.complete();
      _multiConnectCompleter = null;
    }).catchError((Object e) {
      log.info('Failed to connect to device: $e');
      unawaited(Sentry.captureException('Failed to connect to device: $e'));

      _multiConnectCompleter?.completeError(e);
      _multiConnectCompleter = null;
    });
    return _multiConnectCompleter?.future;
  }

  /*
    * Connect to device
    * If autoConnect is true, it will try to connect to device with autoConnect
    * If autoConnect is false, it will try to connect to device without autoConnect
    * If autoConnect is null, it will try to connect to device with autoConnect first, then without autoConnect
   */
  Future<void> _connectDevice(
    BluetoothDevice device, {
    bool shouldShowError = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    log.info('_connectDevice');
    final isDisconnectedWithSuccess = (Object e) {
      if (e is FFBluetoothDisconnectedError && e.disconnectReason?.code == 0) {
        return true;
      }
      return false;
    };
    try {
      await _connect(
        device,
        shouldShowError: (e) {
          if (isDisconnectedWithSuccess(e)) {
            return false;
          }
          return shouldShowError;
        },
        timeout: timeout,
      );
    } catch (e) {
      if (isDisconnectedWithSuccess(e)) {
        log.info("Connection is not stable, retrying...");
        await _connect(
          device,
          shouldShowError: (_) => shouldShowError,
          timeout: timeout,
        );
      } else {
        throw e;
      }
    }
  }

  Future<void> _connect(
    BluetoothDevice device, {
    bool Function(Object e)? shouldShowError,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // connect to device
    if (device.isDisconnected) {
      if (_connectCompleter?.isCompleted == false) {
        log.info(
          '[connect] Already connecting to device: ${device.remoteId.str}',
        );
        return _connectCompleter?.future;
      }
      _connectCompleter = Completer<void>();
      log.info('[connect] Connecting to device: ${device.remoteId.str}');
      try {
        await device.disconnect();

        if (Platform.isAndroid) {
          // Request high connection priority for Android devices
        }
        await Future.delayed(const Duration(milliseconds: 1000));
        await device.connect(
          timeout: timeout,
          mtu: null,
        );
      } catch (e) {
        log.warning('Failed to connect to device: $e');
        unawaited(Sentry.captureException('Failed to connect to device: $e'));
        if (shouldShowError?.call(e) ?? true) {
          unawaited(
            injector<NavigationService>().showCannotConnectToBluetoothDevice(
              device,
              e,
            ),
          );
        }
        _connectCompleter = null;
        rethrow;
      }

      log.info(
        '''[_connect] Wait for _connectCompleter to complete''',
      );
      // Wait for connection to complete
      {
        if (_connectCompleter == null) {
          log.info('[_connect] _connectCompleter is null');
          return;
        }
        final now = DateTime.now();

        final timer = Timer.periodic(
          const Duration(seconds: 1),
          (Timer timer) {
            if (_connectCompleter?.isCompleted == true) {
              timer.cancel();
            } else {
              log.info(
                '[_connect] Waiting for connection to complete: ${DateTime.now().difference(now).inSeconds} seconds',
              );
            }
          },
        );

        await _connectCompleter?.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            log.warning('Timeout waiting for connection to complete');
            if (shouldShowError?.call(e) ?? true) {
              unawaited(
                injector<NavigationService>()
                    .showCannotConnectToBluetoothDevice(
                  device,
                  TimeoutException('Taking too long to connect to device'),
                ),
              );
            }
            throw TimeoutException('Taking too long to connect to device');
          },
        ).catchError((Object e) {
          log.warning('Error waiting for connection to complete: $e');
          timer.cancel();
          unawaited(
            Sentry.captureException(
              'Error waiting for connection to complete: $e',
            ),
          );
          log.info(
            '[_connect] Connection took ${DateTime.now().difference(now).inSeconds} seconds',
          );
          if (shouldShowError?.call(e) ?? true) {
            unawaited(
              injector<NavigationService>().showCannotConnectToBluetoothDevice(
                device,
                e,
              ),
            );
          }
          throw e;
        });
        log.info('Connected to device: ${device.remoteId.str}');
        timer.cancel();
      }
    } else {
      log.info('Device already connected: ${device.remoteId.str}');
    }
  }

  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) {
    final completer = Completer<BluetoothDevice?>();
    startScan(
      timeout: timeout,
      onData: (devices) async {
        final foundDevice = devices.firstWhereOrNull(
          (d) => d.advName == name,
        );
        if (foundDevice != null) {
          log.info('Found device during scan: ${foundDevice.remoteId.str}');
          await FlutterBluePlus.stopScan();
          completer.complete(foundDevice);
          return true;
        }
        return false;
      },
      onError: (dynamic e) {
        log.warning('Error during scan: $e');
        if (!completer.isCompleted) {
          completer.completeError(e as Object);
        }
      },
    ).then((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }).catchError((e) {
      if (!completer.isCompleted) {
        completer.completeError(e as Object);
      }
    });
    return completer.future;
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
    FutureOr<bool> Function(List<BluetoothDevice>)? onData,
    FutureOr<void> Function(dynamic)? onError,
    bool forceScan = false,
  }) async {
    if (!injector<AuthService>().isBetaTester() && !forceScan) {
      return;
    }
    final haftTimeout = timeout ~/ 2;
    bool deviceFound = await _startScan(
      timeout: haftTimeout,
      onData: onData,
      onError: onError,
    );

    if (deviceFound) {
      log.info('Device found during initial scan');
      return;
    }
    deviceFound = await _startScan(
      timeout: haftTimeout,
      onData: onData,
      onError: onError,
    );
    if (!deviceFound) {
      log.info('No device found during second scan');
      Sentry.captureMessage(
        'Device scan completed: device not found',
      );
    }
  }

  Future<bool> _startScan({
    Duration timeout = const Duration(seconds: 30),
    FutureOr<bool> Function(List<BluetoothDevice>)? onData,
    FutureOr<void> Function(dynamic)? onError,
  }) async {
    bool foundDevice = false;
    try {
      await listenForAdapterState();

      await FlutterBluePlus.stopScan();

      await Future.delayed(Duration(milliseconds: 500)); // safe delay

      final connectedDevices = FlutterBluePlus.connectedDevices;
      final shouldStop = await onData?.call(connectedDevices);
      if (shouldStop == true) {
        log.info('BluetoothConnectEventScan startScan: already connected');
        return true;
      }
      StreamSubscription<List<ScanResult>>? scanSubscription;

      final now = DateTime.now();

      scanSubscription = FlutterBluePlus.onScanResults.listen(
        (results) async {
          log.info(
            'BluetoothConnectEventScan onScanResults: ${results.map((r) => '${r.device.advName}-${r.advertisementData.serviceUuids.join(',')}').join(',\n')}',
          );
          final devices = results.map((result) => result.device).toList();
          final shouldStopScan = await onData
              ?.call(devices..addAll(FlutterBluePlus.connectedDevices));
          if (shouldStopScan == true) {
            log.info(
              'Scanned Times: ${DateTime.now().difference(now).inSeconds} seconds',
            );
            foundDevice = true;
            await FlutterBluePlus.stopScan();
          }
        },
        onError: (Object error) {
          log.info(
            'BluetoothConnectEventScan onScanResults error: $error',
          );
          Sentry.captureException(
            'BluetoothConnectEventScan onScanResults error: $error',
          );
          onError?.call(error);
          scanSubscription?.cancel();
        },
      );

      FlutterBluePlus.cancelWhenScanComplete(scanSubscription);
      log.info('BluetoothConnectEventScan startScan');
      await FlutterBluePlus.startScan(
        timeout: timeout, // Updated to 60 seconds
        withServices: [
          Guid(BluetoothManager.serviceUuid),
        ],
      );
      // wait for scan to complete
      while (FlutterBluePlus.isScanningNow) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } catch (e) {
      log.warning('Failed to start scan: $e');
      onError?.call(e);
    } finally {
      log.info('BluetoothConnectEventScan stopScan');
      await FlutterBluePlus.stopScan();
      return foundDevice;
    }
  }

  Future<void> factoryReset(FFBluetoothDevice device) async {
    if (device.isDisconnected) {
      await scanAndConnect(device, timeout: Duration(seconds: 10));
    }

    final res = await sendCommand(
      device: device,
      command: BluetoothCommand.factoryReset,
      request: FactoryResetRequest().toJson(),
      timeout: const Duration(seconds: 30),
    );
    log.info('[factoryReset] res: $res');
  }

  Future<void> sendLog(FFBluetoothDevice device, String? title) async {
    try {
      if (device.isDisconnected) {
        await scanAndConnect(device, timeout: Duration(seconds: 10));
      }
      final userId = injector<AuthService>().getUserId();
      final message = title ?? device.getName;
      final apiKey = Environment.supportApiKey;
      final request =
          SendLogRequest(userId: userId!, title: message, apiKey: apiKey);
      final res = await sendCommand(
        device: device,
        command: BluetoothCommand.sendLog,
        request: request.toJson(),
        timeout: const Duration(seconds: 30),
      );

      log.info('[sendLog] res: $res');
    } catch (e) {
      rethrow;
    } finally {
      await device.disconnect();
    }
  }
}

extension BluetoothCharacteristicExt on BluetoothCharacteristic {
  bool get isWifiConnectCharacteristic {
    return uuid.toString() == BluetoothManager.wifiConnectCharUuid;
  }

  String generateReplyId() {
    final replyId = String.fromCharCodes(
      List.generate(4, (_) => Random().nextInt(26) + 97),
    );
    return replyId;
  }

  Future<void> writeWithRetry(List<int> value) async {
    try {
      await write(value);
    } catch (e) {
      log
        ..info('[writeWithRetry] Error writing: $e')
        ..info('[writeWithRetry] Retrying...');
      if (e is FlutterBluePlusException && e.canIgnore) {
        log.info('[writeWithRetry] Error code 14, ignoring');
        return;
      }
      final device = this.device;
      final isDataLongError = e is Exception && e.isDataLongerThanAllowed;
      if (device.isConnected) {
        if (!isDataLongError) {
          await device.discoverCharacteristics();
        }
        try {
          await write(value, allowLongWrite: isDataLongError);
        } catch (e) {
          log.warning(
            '[writeWithRetry] Failed to write after retry: $e',
          );
          if (e is FlutterBluePlusException && e.canIgnore) {
            log.info('[writeWithRetry] Error code 14, ignoring');
            return;
          }
          unawaited(
            Sentry.captureException(
              'Failed to write after retry: $e',
            ),
          );
          rethrow;
        }
      }
    }
  }
}

abstract class BluetoothRequest {
  const BluetoothRequest();
}

abstract class BluetoothResponse {
  const BluetoothResponse();
}

class EmptyBluetoothResponse extends BluetoothResponse {
  const EmptyBluetoothResponse();
}

class SendWifiCredentialRequest extends BluetoothRequest {
  const SendWifiCredentialRequest({
    required this.ssid,
    required this.password,
  });

  final String ssid;
  final String password;

  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'password': password,
    };
  }
}

class SendWifiCredentialResponse extends BluetoothResponse {
  const SendWifiCredentialResponse({
    required this.topicId,
  });

  final String topicId;
}

class FactoryResetRequest extends BluetoothRequest {
  Map<String, dynamic> toJson() {
    return {};
  }
}

class FactoryResetResponse extends BluetoothResponse {}

class SendLogRequest implements FF1Request {
  SendLogRequest({
    required this.userId,
    required this.title,
    required this.apiKey,
  });

  factory SendLogRequest.fromJson(Map<String, dynamic> json) => SendLogRequest(
        userId: json['userId'] as String,
        apiKey: json['apiKey'] as String,
        title: json['title'] as String?,
      );

  final String userId;
  final String? title;
  final String apiKey;

  @override
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'apiKey': apiKey,
        'title': title,
      };
}

class SendLogResponse extends BluetoothResponse {}

class ScanWifiRequest extends BluetoothRequest {
  const ScanWifiRequest();

  Map<String, dynamic> toJson() {
    return {};
  }
}

class ScanWifiResponse extends BluetoothResponse {
  const ScanWifiResponse({
    required this.result,
  });

  final List<String> result;
}

class KeepWifiRequest extends BluetoothRequest {
  const KeepWifiRequest();

  // toJson
  Map<String, dynamic> toJson() {
    return {};
  }
}

class KeepWifiResponse extends BluetoothResponse {
  const KeepWifiResponse({
    required this.topicId,
  });

  final String topicId;
}

class SetTimezoneRequest implements BluetoothRequest {
  SetTimezoneRequest({required this.timezone, DateTime? time})
      : time = time ?? DateTime.now();

  // datetime formatter in YYYY-MM-DD HH:MM:SS format
  static final DateFormat _dateTimeFormatter =
      DateFormat('yyyy-MM-dd HH:mm:ss');

  final String timezone;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'timezone': timezone,
        'time': _dateTimeFormatter.format(time),
      };
}

class SetTimezoneReply extends BluetoothResponse {
  SetTimezoneReply();

  factory SetTimezoneReply.fromJson(Map<String, dynamic> _) =>
      SetTimezoneReply();
}

extension FlutterBluePlusExceptionExt on FlutterBluePlusException {
  bool get canIgnore {
    return code == 14 ||
        code == 133 ||
        (description?.contains('GATT') ?? false);
  }
}
