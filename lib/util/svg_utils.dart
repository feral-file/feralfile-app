import 'dart:convert';

/// Utility class for SVG processing and conversion
class SvgUtils {
  /// Convert display-p3 color to RGB format
  /// Converts color(display-p3 r g b) to rgb(r, g, b)
  static String convertDisplayP3ToRgb(String svgString) {
    // Pattern to match color(display-p3 r g b) with flexible whitespace
    // Matches: color(display-p3 1.0000 1.0000 0.6000)
    final pattern = RegExp(
      r'color\(display-p3\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)\)',
      caseSensitive: false,
    );

    return svgString.replaceAllMapped(pattern, (match) {
      try {
        final rStr = match.group(1)!.trim();
        final gStr = match.group(2)!.trim();
        final bStr = match.group(3)!.trim();

        final r = double.parse(rStr);
        final g = double.parse(gStr);
        final b = double.parse(bStr);

        // Convert from 0-1 range to 0-255 range and clamp
        final rInt = (r * 255).clamp(0, 255).round();
        final gInt = (g * 255).clamp(0, 255).round();
        final bInt = (b * 255).clamp(0, 255).round();

        return 'rgb($rInt, $gInt, $bInt)';
      } catch (e) {
        // If conversion fails, return original
        return match.group(0)!;
      }
    });
  }

  /// Convert CSS classes to inline styles
  /// Removes <style> tag and applies styles directly to elements
  static String convertCssClassesToInlineStyles(String svgString) {
    // Extract style definitions from <style> tag
    final stylePattern = RegExp(r'<style>(.*?)</style>', dotAll: true);
    final styleMatch = stylePattern.firstMatch(svgString);

    if (styleMatch == null) {
      return svgString; // No style tag found
    }

    final styleContent = styleMatch.group(1)!;
    final Map<String, String> classStyles = {};

    // Parse CSS class definitions: .c0{fill:rgb(255, 255, 153)}
    final classPattern = RegExp(r'\.(\w+)\{([^}]+)\}');
    final classMatches = classPattern.allMatches(styleContent);

    for (final match in classMatches) {
      final className = match.group(1)!;
      final styleValue = match.group(2)!.trim();
      classStyles[className] = styleValue;
    }

    // Remove <style> tag first
    var result = svgString.replaceAll(stylePattern, '');

    // Replace class attributes with inline styles
    // Process each class and replace class="cX" with style="..."
    for (final entry in classStyles.entries) {
      final className = entry.key;
      final styleValue = entry.value;

      // Pattern to match class="className" or class='className'
      // Escape className to handle special regex characters
      final escapedClassName = RegExp.escape(className);

      // Match: class="c0" or class='c0' (with optional spaces around =)
      // Allow class to be first attribute or after space
      final classPatternDouble = RegExp(
          '(\\s+|>)class\\s*=\\s*"$escapedClassName"',
          caseSensitive: false);
      final classPatternSingle = RegExp(
          "(\\s+|>)class\\s*=\\s*'$escapedClassName'",
          caseSensitive: false);

      // Replace class="className" with style="..."
      // Keep the space or > from the match
      result = result.replaceAllMapped(classPatternDouble, (match) {
        final prefix = match.group(1)!;
        return '$prefix style="$styleValue"';
      });
      result = result.replaceAllMapped(classPatternSingle, (match) {
        final prefix = match.group(1)!;
        return '$prefix style="$styleValue"';
      });
    }

    return result;
  }

  /// Extract and convert SVG string from data URI
  /// Handles both base64-encoded and URL-encoded SVG data URIs
  /// Applies display-p3 to RGB conversion and CSS classes to inline styles
  static String? decodeAndConvertSvgDataUri(String dataUri) {
    try {
      // Find the comma that separates the header from the data
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex == -1) {
        return null;
      }

      final dataPart = dataUri.substring(commaIndex + 1);
      final isBase64 = dataUri.substring(0, commaIndex).contains('base64');

      String svgString;

      if (isBase64) {
        // Handle base64-encoded SVG
        var base64Data = dataPart;

        // Try URL decoding in case the base64 is URL-encoded
        try {
          base64Data = Uri.decodeComponent(base64Data);
        } catch (e) {
          // If URL decoding fails, use the original string
        }

        // Decode base64 to bytes, then to string
        final bytes = base64Decode(base64Data);
        svgString = utf8.decode(bytes);
      } else {
        // Handle URL-encoded SVG (not base64)
        svgString = Uri.decodeComponent(dataPart);
      }

      // Convert display-p3 colors to RGB
      svgString = convertDisplayP3ToRgb(svgString);

      // Convert CSS classes to inline styles
      svgString = convertCssClassesToInlineStyles(svgString);

      return svgString;
    } catch (e) {
      return null;
    }
  }
}
