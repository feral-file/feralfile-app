import 'package:flutter/material.dart';

extension ButtonStyleExtensions on ThemeData {
  ButtonStyle get textButtonNoPadding {
    return TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
