import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';

class ImageBackground extends StatelessWidget {
  final Widget child;
  final Color color;

  const ImageBackground(
      {required this.child, this.color = AppColor.auLightGrey, super.key});

  @override
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: BoxDecoration(color: color), child: child);
}
