//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/release_note.dart';

/// Parses a changelogs markdown string and returns a list of release notes
List<ReleaseNote> parseChangeLogs(String changeLogs) {
  final lines = changeLogs.split('\n');
  final releaseNotes = <ReleaseNote>[];

  String? currentDate;
  String? currentFFOSTitle;
  String? currentMobileAppTitle;
  final currentContent = StringBuffer();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Check if this is a date header (##)
    if (isReleaseNoteDateHeader(line)) {
      // Save the previous release note if it exists
      if (currentDate != null) {
        releaseNotes.add(
          ReleaseNote(
            date: currentDate,
            ffOSTitle: currentFFOSTitle,
            mobileAppTitle: currentMobileAppTitle,
            content: currentContent.toString().trim(),
          ),
        );
        currentContent.clear();
      }

      // Start new release note with date
      currentDate = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
      currentFFOSTitle = null;
      currentMobileAppTitle = null;
      currentContent.writeln(line);
      continue;
    }

    // Check if this is a title header (###)
    if (line.trim().startsWith('###')) {
      final title = line.replaceFirst(RegExp(r'^###\s*'), '').trim();

      // Check if this is FF OS section
      if (currentDate != null &&
          currentFFOSTitle == null &&
          title.toLowerCase().contains('ff os')) {
        currentFFOSTitle = title;
      }
      // Check if this is Mobile App section
      else if (currentDate != null &&
          currentMobileAppTitle == null &&
          (title.toLowerCase().contains('mobile app') ||
              title.toLowerCase().contains('mobile'))) {
        currentMobileAppTitle = title;
      }

      currentContent.writeln(line);
      continue;
    }

    // Add line to current content
    if (currentDate != null) {
      currentContent.writeln(line);
    }
  }

  // Add the last release note
  if (currentDate != null) {
    releaseNotes.add(ReleaseNote(
      date: currentDate,
      ffOSTitle: currentFFOSTitle,
      mobileAppTitle: currentMobileAppTitle,
      content: currentContent.toString().trim(),
    ));
  }

  return releaseNotes;
}

/// Checks if a line is a release note date header
bool isReleaseNoteDateHeader(String line) {
  // Date headers start with ## but not ###
  return line.startsWith('##') && !line.startsWith('###');
}
