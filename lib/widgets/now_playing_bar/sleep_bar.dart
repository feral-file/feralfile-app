import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/sleep_mode_indicator.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/top_line.dart';
import 'package:flutter/material.dart';

class NowPlayingSleepBar extends StatelessWidget {
  const NowPlayingSleepBar({super.key});

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
        color: NowPlayingBarTokens.bgInactiveColor,
        borderRadius: BorderRadius.circular(
          NowPlayingBarTokens.cornerRadius.toDouble(),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TopLine(color: PrimitivesTokens.colorsGrey),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sleeping',
                  style: AppTypography.body(context).grey,
                ),
                const SleepModeIndicator(
                  isSleeping: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
