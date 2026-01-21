import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/view/header_with_animated_below.dart';
import 'package:autonomy_flutter/view/now_displaying/now_display_setting.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/display_item.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/sleep_mode_indicator.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/top_line.dart';
import 'package:flutter/material.dart';

final ValueNotifier<bool> isNowDisplayingBarShowingQuickSetting =
    ValueNotifier(false);

class CollapsedNowPlayingBar extends StatefulWidget {
  const CollapsedNowPlayingBar(
      {required this.playingObject, this.onToggle, super.key});
  final DP1NowDisplayingObject playingObject;
  final void Function()? onToggle;

  @override
  State<StatefulWidget> createState() => _CollapsedNowPlayingBarState();
}

class _CollapsedNowPlayingBarState extends State<CollapsedNowPlayingBar>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(CollapsedNowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  DP1NowDisplayingObject get playingObject => widget.playingObject;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: HeaderWithAnimated(
        // maxHeight: widget.maxHeight,
        header: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const TopLine(),
            Row(
              children: [
                Expanded(
                  child: DisplayItem(
                    nowDisplayingItem: playingObject.currentItem,
                    deviceName: playingObject.connectedDevice.name,
                    onTap: () {
                      injector<NavigationService>().navigateTo(
                        AppRouter.nowDisplayingPage,
                      );
                    },
                  ),
                ),
                SizedBox(width: LayoutConstants.space4),
                const SleepModeIndicator(
                  isSleeping: false,
                ),
              ],
            ),
          ],
        ),
        isExpandedListenable: ValueNotifier(false),
        child: const NowDisplayingQuickSettingView(),
      ),
    );
  }
}
