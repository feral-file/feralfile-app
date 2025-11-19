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
  String? currentTitle;
  final currentContent = StringBuffer();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Check if this is a date header (##)
    if (isReleaseNoteDateHeader(line)) {
      // Save the previous release note if it exists
      if (currentDate != null) {
        releaseNotes.add(ReleaseNote(
          date: currentDate,
          title: currentTitle ?? currentDate,
          content: currentContent.toString().trim(),
        ));
        currentContent.clear();
      }

      // Start new release note with date
      currentDate = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
      currentTitle = null;
      currentContent.writeln(line);
      continue;
    }

    // Check if this is a title header (###)
    if (line.trim().startsWith('###')) {
      if (currentDate != null && currentTitle == null) {
        // This is the first title under the date, use it as the release note title
        currentTitle = line.replaceFirst(RegExp(r'^###\s*'), '').trim();
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
      title: currentTitle ?? currentDate,
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

/// Compares two date strings by their position in the changelogs
/// Returns: > 0 if date1 is newer than date2 (appears earlier in changelogs)
///          < 0 if date1 is older than date2 (appears later in changelogs)
///          = 0 if dates are equal
/// Note: Changelogs is ordered newest to oldest
int compareReleaseNoteDates(String changeLogs, String date1, String date2) {
  if (date1 == date2) {
    return 0;
  }

  final lines = changeLogs.split('\n');
  int? date1Index;
  int? date2Index;

  // Find positions of both dates in changelogs
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (isReleaseNoteDateHeader(line)) {
      final dateStr = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
      if (dateStr == date1 && date1Index == null) {
        date1Index = i;
      }
      if (dateStr == date2 && date2Index == null) {
        date2Index = i;
      }

      // Stop searching once both dates are found
      if (date1Index != null && date2Index != null) {
        break;
      }
    }
  }

  // If either date not found, handle edge cases
  if (date1Index == null) {
    // If read date not found, treat as if user hasn't read anything
    return -1; // Current date is newer
  }
  if (date2Index == null) {
    // If current date not found, treat as if already read
    return 1; // Read date is newer
  }

  // Earlier index = newer date (changelog ordered newest to oldest)
  // Return positive if date1 is newer (earlier index)
  return date2Index - date1Index;
}

/// Gets the latest change log date from changelogs
String? getLatestChangeLogDate(String changeLogs) {
  final lines = changeLogs.split('\n');

  // Find the first version date header (##)
  // Changelog is ordered newest to oldest
  for (final line in lines) {
    if (isReleaseNoteDateHeader(line)) {
      return line.replaceFirst(RegExp(r'^##\s*'), '').trim();
    }
  }

  return null;
}

/// Gets release note for a specific date from changelogs
/// Returns null if date not found
String? getReleaseNoteByDate(String changeLogs, String date) {
  final lines = changeLogs.split('\n');
  int? dateHeaderIndex;

  // Find the date header
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (isReleaseNoteDateHeader(line)) {
      final dateStr = line.replaceFirst(RegExp(r'^##\s*'), '').trim();
      if (dateStr == date) {
        dateHeaderIndex = i;
        break;
      }
    }
  }

  if (dateHeaderIndex == null) {
    return null;
  }

  // Find where this date section ends (next date header ## or end of file)
  var dateSectionEnd = lines.length;
  for (var i = dateHeaderIndex + 1; i < lines.length; i++) {
    final line = lines[i];
    if (isReleaseNoteDateHeader(line)) {
      dateSectionEnd = i;
      break;
    }
  }

  // Extract the entire date section (including FF OS and Mobile App)
  final sectionLines = lines.sublist(dateHeaderIndex, dateSectionEnd);

  return sectionLines.join('\n').trim();
}
