import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:roundcheckbox/roundcheckbox.dart';

class RadioSelectAddress extends StatelessWidget {
  final bool? isChecked;
  final Color? checkColor;
  final Color? uncheckColor;
  final Color? borderColor;
  final Function(bool?)? onTap;

  const RadioSelectAddress({
    super.key,
    this.isChecked,
    this.onTap,
    this.checkColor,
    this.uncheckColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoundCheckBox(
      border: Border.all(
        color: borderColor ?? theme.colorScheme.primary,
        width: 1.5,
      ),
      uncheckedColor: uncheckColor ?? theme.colorScheme.primary,
      uncheckedWidget: Container(
        padding: const EdgeInsets.all(4),
      ),
      checkedColor: checkColor ?? theme.colorScheme.primary,
      checkedWidget: Container(
        padding: const EdgeInsets.all(4),
        child: SvgPicture.asset(
          'assets/images/check-icon.svg',
          colorFilter: ColorFilter.mode(
              borderColor ?? theme.colorScheme.primary, BlendMode.srcIn),
        ),
      ),
      animationDuration: const Duration(milliseconds: 100),
      isChecked: isChecked,
      disabledColor: Colors.transparent,
      size: 24,
      onTap: onTap,
    );
  }
}

class AuCheckBox extends StatelessWidget {
  final bool? isChecked;
  final Color? color;

  const AuCheckBox({
    super.key,
    this.isChecked,
    this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        child: SvgPicture.asset(
          isChecked ?? false
              ? 'assets/images/check_box_true.svg'
              : 'assets/images/check_box_false.svg',
          colorFilter:
              ColorFilter.mode(color ?? AppColor.primaryBlack, BlendMode.srcIn),
        ),
      );
}
