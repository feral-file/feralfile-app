import 'package:flutter/material.dart';

import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/build/typography.dart';

/// Central typography system - all font sizes and styles
/// Values come from design tokens (lib/design/tokens/)
class AppTypography {
  AppTypography._();

  static const String ppMori = PrimitivesTokens.fontFamiliesPpMori;
  static const String ibmPlexMono = PrimitivesTokens.fontFamiliesIbmFlexMono;

  /// Get text scale factor from OS accessibility settings
  static double _textScaleFactor(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1.0);
  }

  // Base sizes from tokens (convert to double for TextStyle)
  static final double _displaySize =
      TypographyTokens.displayFontSize.toDouble();
  static final double _h1Size = TypographyTokens.h1FontSize.toDouble();
  static final double _h2Size = TypographyTokens.h2FontSize.toDouble();
  static final double _h3Size = TypographyTokens.h3FontSize.toDouble();
  static final double _h4Size = TypographyTokens.h4FontSize.toDouble();
  static final double _bodySize = TypographyTokens.bodyFontSize.toDouble();
  static final double _bodySmallSize =
      TypographyTokens.bodySmallFontSize.toDouble();
  static final double _captionSize =
      TypographyTokens.captionFontSize.toDouble();
  static final double _verySmallSize =
      TypographyTokens.verySmallFontSize.toDouble();

  /// Display (40px) - Hero text, empty states, key marketing moments
  static TextStyle display(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _displaySize * scale,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  /// H1 (28px) - Page titles, major sections
  static TextStyle h1(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _h1Size * scale,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  /// H2 (22px) - Section headers, onboarding titles, modal titles
  static TextStyle h2(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _h2Size * scale,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
    );
  }

  /// H3 (18px) - Card titles, component headers
  static TextStyle h3(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _h3Size * scale,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
    );
  }

  /// H4 (16px) - Card titles, component headers
  static TextStyle h4(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _h4Size * scale,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
    );
  }

  /// Body (16px) - Default body text, long paragraphs, primary button labels
  /// This is the DEFAULT - use BodySmall only when needed
  static TextStyle body(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _bodySize * scale,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
    );
  }

  /// Body Bold (16px) - Emphasized body text
  static TextStyle bodyBold(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _bodySize * scale,
      fontWeight: FontWeight.w700,
      height: 1.4,
      letterSpacing: 0,
    );
  }

  /// Body Small (14px) - Secondary labels, list subtitles, dense controls
  /// Use sparingly - requires justification ("dense table", "secondary label")
  static TextStyle bodySmall(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _bodySmallSize * scale,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
    );
  }

  /// Body Small Bold (14px)
  static TextStyle bodySmallBold(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _bodySmallSize * scale,
      fontWeight: FontWeight.w700,
      height: 1.4,
      letterSpacing: 0,
    );
  }

  /// Caption (12px) - Low-priority metadata ONLY
  /// Never use as primary way to read something important
  static TextStyle caption(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _captionSize * scale,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.04,
    );
  }

  /// Caption Bold (12px)
  static TextStyle captionBold(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _captionSize * scale,
      fontWeight: FontWeight.w700,
      height: 1.5,
      letterSpacing: 0.04,
    );
  }

  /// Mono (16px) - Addresses, code, technical text
  static TextStyle mono(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ibmPlexMono,
      fontSize: _bodySize * scale,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
    );
  }

  /// Mono Small (14px) - Small technical text
  static TextStyle monoSmall(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ibmPlexMono,
      fontSize: _bodySmallSize * scale,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
    );
  }

  /// Very Small (8px) - Thumbnail text
  static TextStyle verySmall(BuildContext context) {
    final scale = _textScaleFactor(context);
    return TextStyle(
      fontFamily: ppMori,
      fontSize: _verySmallSize * scale,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0,
    );
  }
}

/// Color extensions for TextStyle
extension TypographyColors on TextStyle {
  TextStyle get black => copyWith(color: const Color(0xFF000000));
  TextStyle get white => copyWith(color: const Color(0xFFFFFFFF));
  TextStyle get grey => copyWith(color: const Color(0xFFA0A0A0));
  TextStyle get inactive => copyWith(color: const Color(0xFF999999));
  TextStyle get highlight => copyWith(color: const Color(0xFFECFF0C));
  TextStyle get red => copyWith(color: const Color(0xFFA1200A));
}

extension TypographyFontStyle on TextStyle {
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);
}

extension TypographyFontWeight on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);
  TextStyle get regular => copyWith(fontWeight: FontWeight.w400);
}

//decorations
extension TypographyDecorations on TextStyle {
  TextStyle get underline => copyWith(decoration: TextDecoration.underline);
}
