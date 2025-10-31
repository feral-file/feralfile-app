import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';

/// Mock data factory for device objects
class MockDeviceData {
  /// Create a mock BaseDevice (using a concrete implementation if needed)
  /// Since BaseDevice is abstract, we'll create a mock that extends it
  static MockBaseDevice createDevice({
    String deviceId = 'test_device_1',
    String topicId = 'test_topic_1',
    String name = 'Test Device',
  }) {
    return MockBaseDevice(
      deviceId: deviceId,
      topicId: topicId,
      name: name,
    );
  }

  /// Create list of devices
  static List<MockBaseDevice> createDeviceList({
    int count = 3,
  }) {
    return List.generate(count, (index) {
      return createDevice(
        deviceId: 'test_device_${index + 1}',
        topicId: 'test_topic_${index + 1}',
        name: 'Test Device ${index + 1}',
      );
    });
  }

  /// Create DeviceStatus
  static DeviceStatus createDeviceStatus({
    ScreenOrientation screenRotation = ScreenOrientation.landscape,
    String? connectedWifi,
    String? installedVersion,
    String? latestVersion,
  }) {
    return DeviceStatus(
      screenRotation: screenRotation,
      connectedWifi: connectedWifi ?? 'Test WiFi',
      installedVersion: installedVersion ?? '1.0.0',
      latestVersion: latestVersion ?? '1.0.0',
    );
  }
}

/// Mock implementation of BaseDevice for testing
class MockBaseDevice implements BaseDevice {
  MockBaseDevice({
    required this.deviceId,
    required this.topicId,
    required this.name,
  });

  @override
  final String deviceId;

  @override
  final String topicId;

  @override
  final String name;
}
