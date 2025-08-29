import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/display_item.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/top_line.dart';
import 'package:flutter/material.dart';

class CollapsedNowPlayingBar extends StatelessWidget {
  const CollapsedNowPlayingBar({required this.playingObject, super.key});
  final DP1NowDisplayingObject playingObject;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: NowPlayingBarTokens.collapseHeight.toDouble(),
      padding: EdgeInsets.only(
        top: NowPlayingBarTokens.paddingTop.toDouble(),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const TopLine(),
          Expanded(
            child: DisplayItem(
              deviceName: playingObject.connectedDevice.name,
              assetToken: playingObject.assetToken,
              onTap: () {
                injector<NavigationService>().navigateTo(
                  AppRouter.nowDisplayingPage,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
