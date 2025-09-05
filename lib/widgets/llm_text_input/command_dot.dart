import 'package:autonomy_flutter/design/build/components/CommandDot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CommandDot extends StatelessWidget {
  const CommandDot({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: CommandDotTokens.size.toDouble(),
        height: CommandDotTokens.size.toDouble(),
        decoration: BoxDecoration(
          color: CommandDotTokens.bgColor,
          borderRadius:
              BorderRadius.circular(CommandDotTokens.cornerRadius.toDouble()),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/talk_icon.svg',
            width: CommandDotTokens.iconWidth,
            height: CommandDotTokens.iconHeight.toDouble(),
            colorFilter: const ColorFilter.mode(
              CommandDotTokens.iconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
