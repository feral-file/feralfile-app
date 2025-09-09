import 'package:autonomy_flutter/design/build/components/SendButton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SendButton extends StatelessWidget {
  const SendButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SendButtonTokens.size.toDouble(),
        height: SendButtonTokens.size.toDouble(),
        decoration: const BoxDecoration(
          color: SendButtonTokens.bgColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/images/send_icon.svg',
            colorFilter: const ColorFilter.mode(
              SendButtonTokens.iconColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
