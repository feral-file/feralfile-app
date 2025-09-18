// class mock for CanvasClientService

import 'package:autonomy_flutter/gateway/tv_cast_api.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/device_info_service.dart';

class MockCanvasClientServiceV2 extends CanvasClientServiceV2 {
  MockCanvasClientServiceV2() : super(MockDeviceInfoService(), MockTvCastApi());

  @override
  Future<bool> connectToDevice(BaseDevice device) async {
    return true;
  }

  @override
  Future<void> disconnectDevice(BaseDevice device) async {
    // Mock implementation
  }

  @override
  Future<bool> pauseCasting(BaseDevice device) async {
    return true;
  }

  @override
  Future<bool> resumeCasting(BaseDevice device) async {
    return true;
  }

  @override
  Future<bool> nextArtwork(BaseDevice device, {String? startTime}) async {
    return true;
  }

  @override
  Future<bool> previousArtwork(BaseDevice device, {String? startTime}) async {
    return true;
  }
}

class MockDeviceInfoService extends DeviceInfoService {
  @override
  String get deviceId => 'mock_device_id';

  @override
  String get deviceName => 'Mock Device';
}

class MockTvCastApi implements TvCastApi {
  @override
  Future<dynamic> request({
    required String topicId,
    required Map<String, dynamic> body,
  }) async {
    return {};
  }
}
