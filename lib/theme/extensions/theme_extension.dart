import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

extension TextThemeExtension on TextTheme {
  TextStyle get dateDividerTextStyle {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.auQuickSilver : AppColor.auQuickSilver,
      fontSize: 12,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get sentMessageBodyTextStyle {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 14,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get sentMessageCaptionTextStyle {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 14,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get receivedMessageCaptionTextStyle {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 14,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get receivedMessageBodyTextStyle {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 14,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get atlasGreyNormal14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      fontFamily: AppTheme.atlasGrotesk,
      fontSize: 14,
      color:
          isLightMode ? AppColor.secondaryDimGrey : AppColor.secondaryDimGrey,
      fontWeight: FontWeight.w300,
    );
  }

  TextStyle get atlasWhiteBold12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      fontFamily: AppTheme.atlasGrotesk,
      fontSize: 12,
      color: isLightMode ? AppColor.white : AppColor.white,
      fontWeight: FontWeight.bold,
    );
  }

  TextStyle get atlasGreyNormal12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color:
          isLightMode ? AppColor.secondaryDimGrey : AppColor.secondaryDimGrey,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.atlasGrotesk,
    );
  }

  TextStyle get atlasGreyBold12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color:
          isLightMode ? AppColor.secondaryDimGrey : AppColor.secondaryDimGrey,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.atlasGrotesk,
    );
  }

  TextStyle get linkStyle16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? Colors.transparent : Colors.transparent,
      fontSize: 16,
      fontFamily: AppTheme.atlasGrotesk,
      fontWeight: FontWeight.w400,
      shadows: const [Shadow(offset: Offset(0, -1))],
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.solid,
      decorationColor: Colors.black,
      decorationThickness: 1.1,
    );
  }

  TextStyle get linkStyle14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? Colors.transparent : Colors.transparent,
      fontSize: 14,
      fontFamily: AppTheme.atlasGrotesk,
      fontWeight: FontWeight.w700,
      shadows: const [Shadow(offset: Offset(0, -1))],
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.solid,
      decorationColor: Colors.black,
      decorationThickness: 1.1,
    );
  }

  TextStyle get dateDividerTextStyle14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.auQuickSilver : AppColor.auQuickSilver,
      fontSize: 14,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get sentMessageBodyTextStyle16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 16,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get sentMessageCaptionTextStyle16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 16,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get receivedMessageCaptionTextStyle16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 16,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get receivedMessageBodyTextStyle16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 16,
      fontFamily: AppTheme.ppMori,
    );
  }

  TextStyle get atlasGreyBold14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color:
          isLightMode ? AppColor.secondaryDimGrey : AppColor.secondaryDimGrey,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.atlasGrotesk,
    );
  }

  TextStyle get ppMori700Black36 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400Black16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400Black14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400Black12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700Black16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700Black14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori600Black12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400White12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400White16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400White24 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 24,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700White12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700White14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700White16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400White14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700White24 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700White18 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.white : AppColor.white,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700Black24 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.primaryBlack : AppColor.primaryBlack,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400Grey14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.disabledColor : AppColor.disabledColor,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400Grey12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.disabledColor : AppColor.disabledColor,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400FFYellow14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode
          ? AppColor.feralFileHighlight
          : AppColor.feralFileHighlight,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori700QuickSilver8 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.auQuickSilver : AppColor.auQuickSilver,
      fontSize: 8,
      fontWeight: FontWeight.w700,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400FFQuickSilver12 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.auQuickSilver : AppColor.auQuickSilver,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }

  TextStyle get ppMori400FFQuickSilver14 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? AppColor.auQuickSilver : AppColor.auQuickSilver,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontFamily: AppTheme.ppMori,
      height: 1.4,
    );
  }
}
