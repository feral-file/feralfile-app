import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppTheme {
  static const String ppMori = 'PP Mori';
  // static const moMASans = "MoMASans";

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
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 12,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: ppMori,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.secondaryDimGrey,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 12,
          fontWeight: FontWeight.w300,
          fontFamily: ppMori,
        ),
      ),
      primaryTextTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.white,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.white,
          fontSize: 12,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.white,
          fontSize: 12,
          fontWeight: FontWeight.w300,
          fontFamily: ppMori,
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
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: ppMori,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.secondaryDimGrey,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.primaryBlack,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          fontFamily: ppMori,
        ),
      ),
      primaryTextTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColor.white,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displayMedium: TextStyle(
          color: AppColor.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        displaySmall: TextStyle(
          color: AppColor.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        headlineSmall: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontFamily: ppMori,
        ),
        labelLarge: TextStyle(
          color: AppColor.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodySmall: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: ppMori,
        ),
        bodyLarge: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: ppMori,
          fontWeight: FontWeight.w300,
        ),
        bodyMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleMedium: TextStyle(
          color: AppColor.white,
          fontSize: 20,
          fontFamily: ppMori,
        ),
        titleSmall: TextStyle(
          color: AppColor.white,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          fontFamily: ppMori,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData();
  }
}
