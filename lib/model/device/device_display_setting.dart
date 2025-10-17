import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';

class DeviceDisplaySetting {
  DeviceDisplaySetting({
    this.scaling,
  });

  factory DeviceDisplaySetting.fromJson(Map<String, dynamic> json) {
    return DeviceDisplaySetting(
      scaling: json['scaling'] != null
          ? ArtFraming.fromString(json['scaling'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scaling': scaling?.name,
    };
  }

  DeviceDisplaySetting copyWith({
    ArtFraming? scaling,
  }) {
    return DeviceDisplaySetting(
      scaling: scaling ?? this.scaling,
    );
  }

  ArtFraming? scaling;
}
