import 'dart:convert';

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HighlightController extends TextEditingController {
  List<Map<String, dynamic>> _templates = [];
  bool _templatesLoaded = false;

  HighlightController() {
    _loadTemplates();
  }

  // Load DSL templates from assets
  Future<void> _loadTemplates() async {
    try {
      final String jsonString =
          await rootBundle.loadString('lib/dsl/templates_enriched.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
      _templates = jsonData.cast<Map<String, dynamic>>();
      _templatesLoaded = true;
    } catch (e) {
      print('Error loading templates: $e');
      _templates = [];
      _templatesLoaded =
          true; // Set to true even on error to avoid infinite waiting
    }
  }

  // Extract keywords from input text using DSL regexp patterns
  List<String> getKeywordsFromInput(String inputText) {
    List<String> keywords = [];

    if (!_templatesLoaded) {
      return keywords;
    }

    for (var template in _templates) {
      final String regex = template['regex'] as String;
      final RegExp regExp = RegExp(regex, caseSensitive: false);

      if (regExp.hasMatch(inputText)) {
        final Match? match = regExp.firstMatch(inputText);
        if (match != null) {
          // Extract placeholder values (groups 1, 2, 3, etc.)
          for (int i = 1; i <= match.groupCount; i++) {
            final String? groupValue = match.group(i);
            if (groupValue != null && groupValue.isNotEmpty) {
              keywords.add(groupValue.trim());
            }
          }
        }
      }
    }

    return keywords;
  }

  // Return first matched keyword or full text if no match
  String getMatchOrFull([String? inputOverride]) {
    final String input = inputOverride ?? text;
    final matches = getKeywordsFromInput(input);
    return matches.isNotEmpty ? matches.first : input;
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
            color: AppColor.feralFileLightBlue, fontWeight: FontWeight.bold),
      ));

      start = closestMatchIndex + matchedWord.length;
    }

    return TextSpan(style: style, children: children);
  }
}
