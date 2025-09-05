import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:flutter/material.dart';

class TopLine extends StatelessWidget {
  const TopLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NowPlayingBarTokens.topLineWidth.toDouble(),
      height: NowPlayingBarTokens.topLineHeight.toDouble(),
      decoration: BoxDecoration(
        color: NowPlayingBarTokens.topLineColor,
        borderRadius: BorderRadius.circular(
          NowPlayingBarTokens.topLineCornerRadius.toDouble(),
        ),
      ),
    );
  }
}
