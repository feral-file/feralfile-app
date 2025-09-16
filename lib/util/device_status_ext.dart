import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/log.dart';

extension ListDeviceStatusExtension
    on List<Pair<BaseDevice, CheckCastingStatusReply>> {
  Map<String, CheckCastingStatusReply> get controllingDevices {
    final canvasClientServiceV2 = injector<CanvasClientServiceV2>();
    final Map<String, CheckCastingStatusReply> controllingDeviceStatus = {};
    final thisDevice = canvasClientServiceV2.clientDeviceInfo;
    for (final devicePair in this) {
      final status = devicePair.second;
      if (status.connectedDevice?.deviceId == thisDevice.deviceId ||
          devicePair.first is FFBluetoothDevice) {
        controllingDeviceStatus[devicePair.first.deviceId] = status;
      } else {
        log.info(
            'Device ${devicePair.first.deviceId} is not controlling device');
      }
    }
    return controllingDeviceStatus;
  }
}

extension DeviceStatusExtension on CheckCastingStatusReply {
  String get playingArtworkKey {
    return this.displayKey ?? '';
  }

  DP1Item? get playingItem {
    final items = this.items;
    if (items == null || items.isEmpty) {
      return null;
    }

    final index = this.index;
    if (index == null || index < 0 || index >= items.length) {
      return null;
    }

    return items[index];
  }
}

extension PlayArtworksExtension on List<PlayArtworkV2> {
  int get playArtworksHashCode {
    final hashCodes = map((e) => e.playArtworkHashCode);
    final hashCode = hashCodes.reduce((value, element) => value ^ element);
    return hashCode;
  }
}

extension PlayArtworkExtension on PlayArtworkV2 {
  int get playArtworkHashCode {
    final id = token?.id ?? artwork?.url ?? '';
    return id.hashCode;
  }
}
