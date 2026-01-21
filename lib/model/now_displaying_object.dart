import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/dp1/dp1_manifest.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

abstract class NowDisplayingObjectBase {
  NowDisplayingObjectBase({required this.connectedDevice});

  final BaseDevice connectedDevice;
}

class DP1NowDisplayingObject extends NowDisplayingObjectBase {
  DP1NowDisplayingObject({
    required super.connectedDevice,
    required this.index,
    required this.items,
    required this.isSleeping,
    });

  final int index;
  final List<DP1NowDisplayingItem> items;
  final bool isSleeping;

  DP1NowDisplayingItem get currentItem => items[index];
}

class DP1NowDisplayingItem {
  DP1NowDisplayingItem({
    required this.dp1Item,
    this.assetToken,
    this.dp1Manifest,
  });

  final DP1Item dp1Item;
  final AssetToken? assetToken;
  final DP1Manifest? dp1Manifest;
}
