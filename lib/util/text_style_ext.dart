import 'dart:math';

import 'package:flutter/material.dart';

extension TextStyleExtension on TextStyle {
  static const double _minFontSize = 8.0;

  TextStyle adjustSize(double size) {
    return copyWith(fontSize: max(fontSize! + size, _minFontSize));
  }
}

class FontWeightUtil {
  /// Converts string font weight to Flutter's FontWeight
  static FontWeight fromString(String weight) {
    switch (weight.toLowerCase()) {
      case 'bold':
        return FontWeight.bold;
      case 'semibold':
      case 'semi-bold':
        return FontWeight.w600;
      case 'medium':
        return FontWeight.w500;
      case 'regular':
      case 'normal':
        return FontWeight.normal;
      case 'light':
        return FontWeight.w300;
      case 'extralight':
      case 'extra-light':
        return FontWeight.w200;
      case 'thin':
        return FontWeight.w100;
      default:
        return FontWeight.normal;
    }
  }
}
