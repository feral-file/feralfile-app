// extension for List<PlaylistData>

import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';

extension PlaylistDataExt on List<PlaylistData> {
  // ==
  bool isEqualTo(List<PlaylistData> other) {
    if (identical(this, other)) return true;
    return length == other.length &&
        every((element) => other.contains(element));
  }
}
