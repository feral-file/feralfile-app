import 'package:autonomy_flutter/model/device/base_device.dart';

class FF1DeviceInfo extends BaseDevice {
  FF1DeviceInfo({
    required super.deviceId,
    required super.topicId,
    required this.isConnectedToInternet,
    required this.branchName,
    required this.version,
  });

  @override
  String get name => deviceId;

  final bool isConnectedToInternet;
  final String branchName;
  final String version;
}
