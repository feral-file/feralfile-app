import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/build/typography.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/app_theme.dart';
import 'package:autonomy_flutter/util/text_style_ext.dart';
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

  TextStyle get linkStyle16 {
    final bool isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.light;
    return TextStyle(
      color: isLightMode ? Colors.transparent : Colors.transparent,
      fontSize: 16,
      fontFamily: AppTheme.ppMori,
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
      fontFamily: AppTheme.ppMori,
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


  TextStyle get h1 {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.h1FontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.h1FontWeight),
      fontFamily: TypographyTokens.h1FontFamily,
      height: TypographyTokens.h1LineHeight / TypographyTokens.h1FontSize,
      letterSpacing: TypographyTokens.h1LetterSpacing.toDouble(),
    );
  }

  TextStyle get h2 {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.h2FontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.h2FontWeight),
      fontFamily: TypographyTokens.h2FontFamily,
      height: TypographyTokens.h2LineHeight / TypographyTokens.h2FontSize,
      letterSpacing: TypographyTokens.h2LetterSpacing.toDouble(),
    );
  }

  TextStyle get h3 {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.h3FontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.h3FontWeight),
      fontFamily: TypographyTokens.h3FontFamily,
      height: TypographyTokens.h3LineHeight / TypographyTokens.h3FontSize,
      letterSpacing: TypographyTokens.h3LetterSpacing.toDouble(),
    );
  }

  TextStyle get body {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.bodyFontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.bodyFontWeight),
      fontFamily: TypographyTokens.bodyFontFamily,
      height: TypographyTokens.bodyLineHeight / TypographyTokens.bodyFontSize,
      letterSpacing: TypographyTokens.bodyLetterSpacing.toDouble(),
    );
  }

  TextStyle get title {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.titleFontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.titleFontWeight),
      fontFamily: TypographyTokens.titleFontFamily,
      height: TypographyTokens.titleLineHeight / TypographyTokens.titleFontSize,
      letterSpacing: TypographyTokens.titleLetterSpacing.toDouble(),
    );
  }

  TextStyle get small {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.smallFontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.smallFontWeight),
      fontFamily: TypographyTokens.smallFontFamily,
      height: TypographyTokens.smallLineHeight / TypographyTokens.smallFontSize,
      letterSpacing: TypographyTokens.smallLetterSpacing.toDouble(),
    );
  }

  TextStyle get mono {
    return TextStyle(
      color: PrimitivesTokens.colorsWhite,
      fontSize: TypographyTokens.monoFontSize.toDouble(),
      fontWeight: FontWeightUtil.fromString(TypographyTokens.monoFontWeight),
      fontFamily: TypographyTokens.monoFontFamily,
      height: TypographyTokens.monoLineHeight / TypographyTokens.monoFontSize,
      letterSpacing: TypographyTokens.monoLetterSpacing.toDouble(),
    );
  }
}
