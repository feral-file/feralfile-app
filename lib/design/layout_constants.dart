import 'package:autonomy_flutter/design/build/primitives.dart';

/// Layout and spacing constants from design tokens
/// Based on 4px grid system
class LayoutConstants {
  LayoutConstants._();

  // Spacing scale (4px base unit)
  static final double space1 = PrimitivesTokens.spacingSpace1.toDouble(); // 4px
  static final double space2 = PrimitivesTokens.spacingSpace2.toDouble(); // 8px
  static final double space3 =
      PrimitivesTokens.spacingSpace3.toDouble(); // 12px
  static final double space4 =
      PrimitivesTokens.spacingSpace4.toDouble(); // 16px
  static final double space5 =
      PrimitivesTokens.spacingSpace5.toDouble(); // 20px
  static final double space6 =
      PrimitivesTokens.spacingSpace6.toDouble(); // 24px
  static final double space8 =
      PrimitivesTokens.spacingSpace8.toDouble(); // 32px
  static final double space10 =
      PrimitivesTokens.spacingSpace10.toDouble(); // 40px
  static final double space12 =
      PrimitivesTokens.spacingSpace12.toDouble(); // 48px
  static final double space16 =
      PrimitivesTokens.spacingSpace16.toDouble(); // 64px
  static final double space20 =
      PrimitivesTokens.spacingSpace20.toDouble(); // 80px

  // Page padding
  static final double setupPageHorizontal =
      PrimitivesTokens.spacingSetupPageHorizontal.toDouble(); // 44px
  static final double pageHorizontalDefault =
      PrimitivesTokens.spacingPageHorizontalDefault.toDouble(); // 16px

  // Touch targets
  static final double minTouchTarget =
      PrimitivesTokens.spacingMinTouchTarget.toDouble(); // 44px
  static const double buttonHeightDefault = 44.0;
  static const double buttonHeightLarge = 52.0;

  // Icon sizes
  static final double iconSizeSmall =
      PrimitivesTokens.iconSizesSmall.toDouble(); // 12px
  static final double iconSizeDefault =
      PrimitivesTokens.iconSizesDefault.toDouble(); // 16px
  static final double iconSizeMedium =
      PrimitivesTokens.iconSizesMedium.toDouble(); // 20px
  static final double iconSizeLarge =
      PrimitivesTokens.iconSizesLarge.toDouble(); // 24px
}
