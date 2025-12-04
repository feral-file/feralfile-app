//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//

// Always write code/comment in English
// ignore_for_file: undefined_import, uri_does_not_exist
import 'package:flutter/services.dart' show rootBundle;

abstract class DLSService {
  List<String> extractIdentities(String command);
  Future<void> init();
}

class DLSServiceImpl implements DLSService {
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    // Load the TS file as plain text from assets
    final tsCode = await rootBundle.loadString('lib/dsl/bundle.js');
    // Very naive transform: strip TypeScript type annotations and exports to run in JS runtime
    _initialized = true;
  }

  @override
  List<String> extractIdentities(
    String command,
  ) {
    return command.split(' ');
  }
}
