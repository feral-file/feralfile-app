import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/device_status_ext.dart';

extension CanvasDeviceStatePlayingExt on CanvasDeviceState {
  bool isAssetPlayingOnFF1(AssetToken asset) {
    final playingDevice = BluetoothDeviceManager().castingBluetoothDevice;
    if (playingDevice == null) {
      return false;
    }

    final playingItem = statusOf(playingDevice)?.playingItem;
    if (playingItem == null) {
      return false;
    }

    return playingItem.cid == asset.cid;
  }
}
