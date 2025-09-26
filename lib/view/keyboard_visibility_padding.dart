import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class KeyboardVisibilityPadding extends StatelessWidget {
  const KeyboardVisibilityPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyboardVisibilityBuilder(builder: (context, isKeyboardVisible) {
      return Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: child,
      );
    });
  }
}
