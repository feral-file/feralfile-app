import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/device_sub_nav.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/display_item_list.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/top_line.dart';
import 'package:flutter/material.dart';

class ExpandedNowPlayingBar extends StatelessWidget {
  const ExpandedNowPlayingBar({required this.playingObject, super.key});
  final DP1NowDisplayingObject playingObject;

  @override
  Widget build(BuildContext context) {
    final playlist = DP1CallExtension.fromItems(
      items: playingObject.dp1Items,
    );
    final selectedIndex = playingObject.index;

    return Container(
      constraints: BoxConstraints(
        maxHeight: NowPlayingBarTokens.expandedHeight.toDouble(),
      ),
      padding: EdgeInsets.only(
        top: NowPlayingBarTokens.paddingTop -
            NowPlayingBarTokens.topLineStrokeWeight / 2,
        right: NowPlayingBarTokens.paddingHorizontal.toDouble(),
        bottom: NowPlayingBarTokens.paddingBottom.toDouble(),
        left: NowPlayingBarTokens.paddingHorizontal.toDouble(),
      ),
      decoration: BoxDecoration(
        color: NowPlayingBarTokens.bgColor,
        borderRadius: BorderRadius.circular(
          NowPlayingBarTokens.cornerRadius.toDouble(),
        ),
      ),
      child: Column(
        children: [
          const TopLine(),
          SizedBox(
            height: NowPlayingBarTokens.bottomVerticalGap.toDouble(),
          ),
          const DeviceSubNav(),
          SizedBox(
            height: NowPlayingBarTokens.bottomVerticalGap.toDouble(),
          ),
          Expanded(
            child: DisplayItemList(
              playlist: playlist,
              selectedIndex: selectedIndex,
            ),
          ),
        ],
      ),
    );
  }
}
