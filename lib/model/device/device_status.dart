import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';

class DeviceStatus {
  DeviceStatus({
    required this.screenRotation,
    this.connectedWifi,
    this.installedVersion,
    this.latestVersion,
    this.macAddress,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      connectedWifi: json['connectedWifi'] as String?,
      screenRotation:
          ScreenOrientation.fromString(json['screenRotation'] as String),
      installedVersion: json['installedVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      macAddress: json['macAddress'] as String?,
    );
  }

  final String? connectedWifi;
  final ScreenOrientation screenRotation;
  final String? installedVersion;
  final String? latestVersion;
  final String? macAddress;

  Map<String, dynamic> toJson() {
    return {
      'connectedWifi': connectedWifi,
      'screenRotation': screenRotation.name,
      'installedVersion': installedVersion,
      'latestVersion': latestVersion,
      'macAddress': macAddress,
    };
  }

  DeviceStatus copyWith({
    ScreenOrientation? screenRotation,
    String? connectedWifi,
    String? installedVersion,
    String? latestVersion,
    String? macAddress,
  }) {
    return DeviceStatus(
      screenRotation: screenRotation ?? this.screenRotation,
      connectedWifi: connectedWifi ?? this.connectedWifi,
      installedVersion: installedVersion ?? this.installedVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      macAddress: macAddress ?? this.macAddress,
    );
  }
}
