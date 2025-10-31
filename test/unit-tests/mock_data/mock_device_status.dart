import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';

class MockDeviceStatusData {
  static DeviceStatus basic({
    String rotation = 'landscape',
    String? wifi = 'Test WiFi',
    String? installed = '1.0.0',
    String? latest = '1.0.0',
  }) {
    return DeviceStatus(
      screenRotation: ScreenOrientation.fromString(rotation),
      connectedWifi: wifi,
      installedVersion: installed,
      latestVersion: latest,
    );
  }
}
