import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';

extension DP1PlaylistItemExtension on DP1Item {
  static DP1Item fromAssetToken({
    required AssetToken token,
    Duration duration = Duration.zero,
    ArtworkDisplayLicense license = ArtworkDisplayLicense.open,
  }) {
    return DP1Item(
      title: token.title!,
      source: token.previewURL!,
      duration: duration.inSeconds,
      license: license,
      provenance: token.dp1Provenance,
    );
  }
}
