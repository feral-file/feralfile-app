import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppTheme {
  static const String atlasGrotesk = 'AtlasGrotesk';
  static const String domaineSansText = 'DomaineSansText';
  static const String iBMPlexMono = 'IBMPlexMono';
  static const String ppMori = 'PPMori';
  static const moMASans = "MoMASans";

  final bool _isLightMode =
      SchedulerBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.light;

  bool get isLightMode => _isLightMode;

  static ThemeData lightTheme() {
    return ThemeData(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColor.auQuickSilver,
        selectionHandleColor: AppColor.auQuickSilver,
        selectionColor: AppColor.auQuickSilver,
      ),
      primaryColor: AppColor.primaryBlack,
      scaffoldBackgroundColor: AppColor.white,
      colorScheme: const ColorScheme(
        primary: AppColor.primaryBlack,
        onPrimary: AppColor.primaryBlack,
        secondary: AppColor.white,
        onSecondary: AppColor.white,
        background: AppColor.white,
        onBackground: AppColor.white,
        brightness: Brightness.light,
        error: AppColor.red,
        onError: AppColor.red,
        surface: AppColor.secondaryDimGrey,
        onSurface: AppColor.auLightGrey,
      ),
      primaryIconTheme:
          const IconThemeData(color: AppColor.primaryBlack, size: 24),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displayMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displaySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 12,
          fontFamily: atlasGrotesk,
        ),
        labelLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodyLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: atlasGrotesk,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.secondaryDimGrey,
          fontSize: 16,
          fontFamily: iBMPlexMono,
        ),
        titleMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: iBMPlexMono,
        ),
        titleSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 12,
          fontWeight: FontWeight.w300,
          fontFamily: iBMPlexMono,
        ),
      ),
      primaryTextTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.white,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displayMedium: TextStyle(
          color: AppColor.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displaySmall: TextStyle(
          color: AppColor.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineSmall: TextStyle(
          color: AppColor.white,
          fontSize: 12,
          fontFamily: atlasGrotesk,
        ),
        labelLarge: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodySmall: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodyLarge: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: atlasGrotesk,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: iBMPlexMono,
        ),
        titleMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: iBMPlexMono,
        ),
        titleSmall: TextStyle(
          color: AppColor.white,
          fontSize: 12,
          fontWeight: FontWeight.w300,
          fontFamily: iBMPlexMono,
        ),
      ),
    );
  }

  static ThemeData tabletLightTheme() {
    return ThemeData(
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColor.auQuickSilver,
        selectionHandleColor: AppColor.auQuickSilver,
        selectionColor: AppColor.auQuickSilver,
      ),
      primaryColor: AppColor.primaryBlack,
      scaffoldBackgroundColor: AppColor.white,
      colorScheme: const ColorScheme(
        primary: AppColor.primaryBlack,
        onPrimary: AppColor.primaryBlack,
        secondary: AppColor.white,
        onSecondary: AppColor.white,
        background: AppColor.white,
        onBackground: AppColor.white,
        brightness: Brightness.light,
        error: AppColor.red,
        onError: AppColor.red,
        surface: AppColor.secondaryDimGrey,
        onSurface: AppColor.secondaryDimGrey,
      ),
      primaryIconTheme:
          const IconThemeData(color: AppColor.primaryBlack, size: 24),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displayMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displaySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontFamily: atlasGrotesk,
        ),
        labelLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodyLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: atlasGrotesk,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.secondaryDimGrey,
          fontSize: 20,
          fontFamily: iBMPlexMono,
        ),
        titleMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: iBMPlexMono,
        ),
        titleSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          fontFamily: iBMPlexMono,
        ),
      ),
      primaryTextTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.white,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displayMedium: TextStyle(
          color: AppColor.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        displaySmall: TextStyle(
          color: AppColor.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: atlasGrotesk,
        ),
        headlineSmall: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontFamily: atlasGrotesk,
        ),
        labelLarge: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodySmall: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: iBMPlexMono,
        ),
        bodyLarge: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: atlasGrotesk,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: iBMPlexMono,
        ),
        titleMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: iBMPlexMono,
        ),
        titleSmall: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          fontFamily: iBMPlexMono,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData();
  }
}
