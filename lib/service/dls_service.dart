//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//

// Always write code/comment in English
// ignore_for_file: undefined_import, uri_does_not_exist
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/flutter_js.dart';

abstract class DLSService {
  List<String> extractIdentities(String command);
  Future<void> init();
}

class DLSServiceImpl implements DLSService {
  DLSServiceImpl() : _jsRuntime = getJavascriptRuntime();

  final JavascriptRuntime _jsRuntime;
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    // Load the TS file as plain text from assets
    final tsCode = await rootBundle.loadString('lib/dsl/bundle.js');
    // Very naive transform: strip TypeScript type annotations and exports to run in JS runtime
    _jsRuntime.evaluate(tsCode);
    _initialized = true;
  }

  @override
  List<String> extractIdentities(
    String command,
  ) {
    try {
      var output = _jsRuntime.evaluate('extractIdentities("$command")');
      final raw = output.stringResult.trim();

      // Convert formats like "[h]", "[\"h\"]", "h", or "h, i" to List<String>
      String normalized = raw;
      if (normalized.startsWith('[') && normalized.endsWith(']')) {
        normalized = normalized.substring(1, normalized.length - 1);
      }

      if (normalized.trim().isEmpty) {
        return <String>[];
      }

      final parts = normalized.split(',');
      final results = <String>[];
      for (final part in parts) {
        var token = part.trim();
        if ((token.startsWith('"') && token.endsWith('"')) ||
            (token.startsWith("'") && token.endsWith("'"))) {
          token = token.substring(1, token.length - 1);
        }
        if (token.isNotEmpty) {
          results.add(token);
        }
      }
      return results;
    } catch (e) {
      return <String>[];
    }
  }
}
