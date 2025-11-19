//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:http/http.dart' as http;

int compareVersion(String version1, String version2) {
  List<int> parseVersion(String version) {
    final regex = RegExp(r'^([\d.]+)(?:\((\d+)\))?$');
    final match = regex.firstMatch(version.trim());

    if (match == null) return [];

    final base = match.group(1)!;
    final build = match.group(2);

    final baseParts = base.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    if (build != null) {
      baseParts.add(int.tryParse(build) ?? 0); // Add build number as 4th part
    }
    return baseParts;
  }

  final ver1 = parseVersion(version1);
  final ver2 = parseVersion(version2);

  final maxLength = ver1.length > ver2.length ? ver1.length : ver2.length;

  for (int i = 0; i < maxLength; i++) {
    final v1 = i < ver1.length ? ver1[i] : 0;
    final v2 = i < ver2.length ? ver2[i] : 0;
    final diff = v1 - v2;
    if (diff != 0) return diff;
  }

  return 0; // equal
}

Future<http.Response> callRequest(Uri uri) async {
  return await http.get(uri, headers: {
    "Connection": "Keep-Alive",
    "Keep-Alive": "timeout=5, max=1000"
  });
}

String? getVariantFromCloudFlareImageUrl(String url) {
  final RegExp regex = RegExp(r'^https?://[^/]+/[^/]+/[^/]+/([^/]+)$');
  final Match? match = regex.firstMatch(url);
  if (match != null && match.groupCount == 1) {
    return match.group(1);
  } else {
    return null;
  }
}
