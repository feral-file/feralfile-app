import 'dart:async';

import 'package:autonomy_flutter/design/build/components/PlayButton.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    this.onTap,
    this.enabled = true,
    this.isProcessing = false,
    this.text = 'Play',
  });

  final VoidCallback? onTap;
  final bool enabled;
  final bool isProcessing;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: PlayButtonTokens.paddingHorizontal.toDouble(),
          vertical: PlayButtonTokens.paddingVertical.toDouble(),
        ),
        decoration: BoxDecoration(
          color: PlayButtonTokens.bgColor,
          borderRadius: BorderRadius.circular(
            PlayButtonTokens.cornerRadius.toDouble(),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.small.copyWith(
                    color: PlayButtonTokens.color,
                  ),
            ),
            SizedBox(width: PlayButtonTokens.gap.toDouble()),
            Stack(
              children: [
                SvgPicture.asset(
                  'assets/images/play_icon.svg',
                  width: PlayButtonTokens.iconWidth,
                  height: PlayButtonTokens.iconHeight.toDouble(),
                  colorFilter: const ColorFilter.mode(
                    PlayButtonTokens.color,
                    BlendMode.srcIn,
                  ),
                ),
                if (isProcessing)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: ProcessingIndicator(),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class ProcessingIndicator extends StatefulWidget {
  const ProcessingIndicator({super.key});

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator> {
  int _colorIndex = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _colorIndex = (_colorIndex + 1) % 2;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return dot with color flicker
    final colors = [
      AppColor.primaryBlack,
      AppColor.feralFileLightBlue,
    ];
    final color = colors[_colorIndex];
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
