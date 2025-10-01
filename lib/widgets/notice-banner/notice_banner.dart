import 'package:autonomy_flutter/design/build/components/NoticeBanner.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    super.key,
    this.onTap,
    this.onClose,
    this.minHeight,
  });
  final String message;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: NoticeBannerTokens.padding.toDouble()),
        decoration: BoxDecoration(
          color: NoticeBannerTokens.bgColor,
          borderRadius: BorderRadius.circular(
            NoticeBannerTokens.cornerRadius.toDouble(),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.small,
              ),
            ),
            _CloseButton(onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.all(NoticeBannerTokens.padding.toDouble()),
        child: SvgPicture.asset(
          'assets/images/close.svg',
          width: NoticeBannerTokens.iconSize.toDouble(),
          height: NoticeBannerTokens.iconSize.toDouble(),
          colorFilter: const ColorFilter.mode(
            NoticeBannerTokens.color,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
