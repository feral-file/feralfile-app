import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/constants.dart';

extension DP1CallExtension on DP1Call {
  // static DP1Call fromCompactedAssetToken({
  //   required List<CompactedAssetToken> tokens,
  //   required Duration duration,
  //   required ArtworkDisplayLicense license,
  //   String? playlistId,
  // }) {
  //   final items = tokens
  //       .map(
  //         (token) => DP1PlaylistItemExtension.fromCompactedAssetToken(
  //           token: token,
  //           duration: duration,
  //           license: license,
  //         ),
  //       )
  //       .toList();
  //   return DP1CallExtension.fromItems(
  //     items: items,
  //     playlistId: playlistId,
  //   );
  // }

  static DP1Call fromItems({
    required List<DP1Item> items,
    String? playlistId,
  }) {
    return DP1Call(
        dpVersion: DP_VERSION,
        id: playlistId ?? '',
        slug: '',
        title: 'Playlist',
        created: DateTime.now(),
        items: items,
        defaults: {},
        signature: '0x17794533e25b08');
  }

  String get channelName => 'Feral File';
}
