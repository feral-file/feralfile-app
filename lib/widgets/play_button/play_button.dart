import 'package:autonomy_flutter/design/build/components/PlayButton.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    this.onTap,
    this.enabled = true,
    this.text = 'Play',
  });

  final VoidCallback? onTap;
  final bool enabled;
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
            SvgPicture.asset(
              'assets/images/play_icon.svg',
              colorFilter: const ColorFilter.mode(
                PlayButtonTokens.color,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
