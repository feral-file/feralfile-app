import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';

extension DP1PlaylistItemExtension on DP1Item {
  static DP1Item fromAssetToken({
    required AssetToken token,
    Duration duration = Duration.zero,
    ArtworkDisplayLicense license = ArtworkDisplayLicense.open,
  }) {
    final dp1Contract = DP1Contract(
        chain: DP1ProvenanceChain.fromString(token.chain),
        standard: DP1ProvenanceStandard.fromString(token.standard),
        address: token.contractAddress,
        tokenId: token.tokenNumber);
    final dp1Provenance =
        DP1Provenance(type: DP1ProvenanceType.onChain, contract: dp1Contract);
    return DP1Item(
      id: token.cid,
      title: token.displayTitle,
      source: token.previewUrl,
      duration: duration.inSeconds,
      license: license,
      provenance: dp1Provenance,
    );
  }
}
