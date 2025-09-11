import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/bluetooth_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sentry/sentry.dart';

extension BluetoothDeviceExtension on BluetoothDevice {
  FFBluetoothDevice toFFBluetoothDevice(
      {String? topicId, required String deviceId, required String branchName}) {
    return FFBluetoothDevice.fromBluetoothDevice(this,
        topicId: topicId, deviceId: deviceId, branchName: branchName);
  }

  BluetoothCharacteristic? get wifiConnectCharacteristic =>
      BluetoothManager.getWifiConnectCharacteristic(remoteId.str);

  String get getName {
    final savedName = BluetoothDeviceManager.pairedDevices
        .firstWhereOrNull(
          (e) => e.remoteID == remoteId.str,
        )
        ?.name;
    if (savedName != null) {
      return savedName;
    }

    final name = advName;
    if (name.isNotEmpty) {
      return name;
    }
    return 'FF1';
  }

  Future<void> discoverCharacteristics() async {
    const timeouts = [
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 15)
    ];

    for (int i = 0; i < timeouts.length; i++) {
      try {
        log.info(
            'Attempt ${i + 1}/${timeouts.length} to discover characteristics for device: ${remoteId.str} with timeout: ${timeouts[i]}s');
        await _discoverCharacteristics(timeout: timeouts[i]);
        log.info('Successfully discovered characteristics on attempt ${i + 1}');
        return; // Success, exit the retry loop
      } catch (e) {
        log.warning('Attempt ${i + 1} failed: $e');
        if (i == timeouts.length - 1) {
          // Last attempt failed, rethrow the exception
          log.info('All attempts to discover characteristics failed');
          unawaited(Sentry.captureException(e));
          rethrow;
        }
        if (Platform.isAndroid) {
          // On Android, clear the GATT cache if the device is not connected
          log.info('Clearing GATT cache for device: ${remoteId.str}');
          await this.clearGattCache();
        }
        // Wait a bit before the next attempt
        await Future<void>.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> _discoverCharacteristics({required Duration timeout}) async {
    try {
      log.info(
          'Discovering characteristics for device: ${remoteId.str} with timeout: ${timeout}s');
      await Future<void>.delayed(const Duration(seconds: 1));
      final discoveredServices = await discoverServices(
          timeout: timeout.inSeconds); // Convert to milliseconds

      final services = <BluetoothService>[]
        ..clear()
        ..addAll(discoveredServices);

      final primaryService = services.firstWhereOrNull(
        (service) => service.isPrimary,
      );

      if (primaryService == null) {
        log.warning('Primary service not found');
        unawaited(Sentry.captureMessage('Primary service not found'));
        throw Exception('Primary service not found');
      } else {
        log.info('Primary service found: ${primaryService.uuid}');
      }

      // if the command and wifi connect characteristics are not found, try to find them
      final commandService = services.firstWhereOrNull(
        (service) => service.uuid.toString() == BluetoothManager.serviceUuid,
      );

      if (commandService == null) {
        unawaited(Sentry.captureMessage('Command service not found'));
        throw Exception('Command service not found');
      }
      final wifiConnectChar = commandService.characteristics.firstWhere(
        (characteristic) => characteristic.isWifiConnectCharacteristic,
      );

      // Set the command and wifi connect characteristics
      BluetoothManager.setWifiConnectCharacteristic(wifiConnectChar);

      if (!wifiConnectChar.properties.notify) {
        log.warning('Command characteristic does not support notifications!');
        unawaited(
          Sentry.captureMessage(
            'Command characteristic does not support notifications',
          ),
        );
        throw Exception(
          'Command characteristic does not support notifications',
        );
      }

      try {
        await wifiConnectChar.setNotifyValue(true);
        log.info('Successfully enabled notifications for command char');
      } catch (e) {
        log.warning('Failed to enable notifications for command char: $e');
        unawaited(
          Sentry.captureException('Failed to enable notifications: $e'),
        );
        rethrow;
      }
    } catch (e) {
      log.warning('Error discovering characteristics: $e');
      unawaited(Sentry.captureException(e));
      rethrow; // Rethrow to allow retry logic to handle it
    }
  }
}
