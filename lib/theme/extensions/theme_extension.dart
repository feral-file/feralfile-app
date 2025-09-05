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
