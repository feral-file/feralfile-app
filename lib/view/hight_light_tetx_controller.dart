// Removed: json import not needed after simplifying template extraction
// import 'dart:convert';
import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/dls_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
// Removed: services import not needed after simplifying template extraction
// import 'package:flutter/services.dart';

class HighlightController extends TextEditingController {
  // Rotating placeholder support
  final List<String> _rotatingPlaceholders;
  final Duration _rotationInterval;
  Timer? _placeholderTimer;
  int _placeholderIndex = 0;
  // Expose current placeholder for UI binding (e.g., ValueListenableBuilder)
  final ValueNotifier<String?> placeholderNotifier =
      ValueNotifier<String?>(null);

  HighlightController({
    String? text,
    List<String>? placeholders,
    Duration rotationInterval = const Duration(seconds: 3),
  })  : _rotatingPlaceholders = placeholders ?? const <String>[],
        _rotationInterval = rotationInterval,
        super(text: text) {
    // Start rotating placeholders if provided and input is empty
    addListener(_onTextChanged);
    _maybeStartPlaceholderRotation();
  }

  // Handle text changes to pause/resume placeholder rotation
  void _onTextChanged() {
    // When user types something, hide placeholder and stop timer
    if (text.isNotEmpty) {
      _stopPlaceholderRotation();
      placeholderNotifier.value = null;
    } else {
      // Resume rotation only if we have placeholders
      _maybeStartPlaceholderRotation();
    }
  }

  void _maybeStartPlaceholderRotation() {
    if (_rotatingPlaceholders.isEmpty) return;
    if (text.isNotEmpty) return;
    if (_placeholderTimer?.isActive == true) return;

    // Immediately show current placeholder
    placeholderNotifier.value =
        _rotatingPlaceholders[_placeholderIndex % _rotatingPlaceholders.length];

    _placeholderTimer = Timer.periodic(_rotationInterval, (_) {
      if (text.isNotEmpty) {
        // Safety: stop if user types while timer is running
        _stopPlaceholderRotation();
        return;
      }
      _placeholderIndex =
          (_placeholderIndex + 1) % _rotatingPlaceholders.length;
      placeholderNotifier.value = _rotatingPlaceholders[_placeholderIndex];
    });
  }

  void _stopPlaceholderRotation() {
    _placeholderTimer?.cancel();
    _placeholderTimer = null;
  }

  @override
  void dispose() {
    _stopPlaceholderRotation();
    placeholderNotifier.dispose();
    removeListener(_onTextChanged);
    super.dispose();
  }

  // Extract keywords from input text using DLS service
  List<String> getKeywordsFromInput(String inputText) {
    return injector<DLSService>().extractIdentities(inputText);
  }

  // Return first matched keyword or full text if no match
  List<String> getMatchOrFull([String? inputOverride]) {
    final String input = inputOverride ?? text;
    final matches = getKeywordsFromInput(input);
    return matches;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    final List<TextSpan> children = [];

    // Get keywords dynamically from input text using DSL patterns
    final keywords = getKeywordsFromInput(text);

    if (keywords.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    int start = 0;
    final lowerText = text.toLowerCase();

    while (start < text.length) {
      int closestMatchIndex = text.length;
      String? matchedWord;

      for (var word in keywords) {
        int index = lowerText.indexOf(word.toLowerCase(), start);
        if (index >= 0 && index < closestMatchIndex) {
          closestMatchIndex = index;
          matchedWord = word;
        }
      }

      if (matchedWord == null) {
        children.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (closestMatchIndex > start) {
        children.add(TextSpan(
            text: text.substring(start, closestMatchIndex), style: style));
      }

      children.add(TextSpan(
        text: text.substring(
            closestMatchIndex, closestMatchIndex + matchedWord.length),
        style: style?.copyWith(
          color: AppColor.feralFileHighlight,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = closestMatchIndex + matchedWord.length;
    }

    return TextSpan(style: style, children: children);
  }
}
