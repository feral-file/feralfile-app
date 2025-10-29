import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';

class MockFFBluetoothDeviceData {
  static FFBluetoothDevice create({
    String name = 'My Device',
    String remoteID = 'remote-001',
    String topicId = 'topic_123',
    String deviceId = 'device_123',
    String branchName = 'release',
  }) {
    return FFBluetoothDevice(
      name: name,
      remoteID: remoteID,
      topicId: topicId,
      deviceId: deviceId,
      branchName: branchName,
    );
  }
}
