import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';

abstract class NowDisplayingObjectBase {
  NowDisplayingObjectBase({required this.connectedDevice});

  final BaseDevice connectedDevice;

  List<AssetToken> get assetTokens;
}

class DP1NowDisplayingObject extends NowDisplayingObjectBase {
  DP1NowDisplayingObject({
    required super.connectedDevice,
    required this.index,
    required this.dp1Items,
    required this.assetTokens,
  });

  final int index;
  final List<DP1Item> dp1Items;
  final List<AssetToken> assetTokens;

  DP1Item get playlistItem => dp1Items[index];

  AssetToken get assetToken => assetTokens[index];
}
