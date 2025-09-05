import 'package:autonomy_flutter/design/build/components/BackButton.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomBackButton extends StatelessWidget {
  const CustomBackButton({
    super.key,
    this.onTap,
    this.title = 'Index',
  });

  final VoidCallback? onTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/arrow-left.svg',
            width: BackButtonTokens.iconWidth,
            height: BackButtonTokens.iconHeight.toDouble(),
            colorFilter: const ColorFilter.mode(
              BackButtonTokens.color,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: BackButtonTokens.gap.toDouble()),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .small
                .copyWith(color: BackButtonTokens.color),
          ),
        ],
      ),
    );
  }
}
