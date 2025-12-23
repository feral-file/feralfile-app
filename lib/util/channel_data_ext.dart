/// extension for List<ChannelData>

import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel/channel_section.dart';

extension ChannelDataExt on List<ChannelData> {
  // ==
  bool isEqualTo(List<ChannelData> other) {
    if (identical(this, other)) return true;
    return length == other.length &&
        every((element) => other.contains(element));
  }
}
