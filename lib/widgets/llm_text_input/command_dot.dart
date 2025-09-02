import 'package:autonomy_flutter/design/build/components/CommandDot.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CommandDot extends StatelessWidget {
  const CommandDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CommandDotTokens.size.toDouble(),
      height: CommandDotTokens.size.toDouble(),
      decoration: BoxDecoration(
        color: PrimitivesTokens.colorsLightBlue,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/talk_icon.svg',
          width: 9.82,
          height: 12,
          colorFilter: const ColorFilter.mode(
            PrimitivesTokens.colorsBlack,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
