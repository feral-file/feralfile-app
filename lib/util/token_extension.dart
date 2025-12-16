//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:collection/collection.dart';

/// Extension methods for sorting AssetToken lists
extension AssetTokenSorting on List<v2.AssetToken> {
  /// Sort tokens by provenance event timestamp (descending).
  /// Tokens without provenance events are placed at the end.
  ///
  /// [filterAddresses] - Optional list of addresses to filter relevant provenance events.
  /// If provided, will prioritize events where the address is fromAddress or toAddress.
  void sortByProvenance({List<String>? filterAddresses}) {
    sort((a, b) {
      // Check if provenance exists and has items
      final hasProvenanceA = a.provenanceEvents?.items != null &&
          a.provenanceEvents!.items.isNotEmpty;
      final hasProvenanceB = b.provenanceEvents?.items != null &&
          b.provenanceEvents!.items.isNotEmpty;

      // Both tokens have no provenance - keep original order
      if (!hasProvenanceA && !hasProvenanceB) {
        return 0;
      }

      // Only B has no provenance - B goes last
      if (!hasProvenanceB) {
        return -1;
      }

      // Only A has no provenance - A goes last
      if (!hasProvenanceA) {
        return 1;
      }

      // Both have provenance - find latest relevant event
      final latestProvenanceEventA = _findLatestProvenanceEvent(
        a.provenanceEvents!.items,
        filterAddresses,
      );
      final latestProvenanceEventB = _findLatestProvenanceEvent(
        b.provenanceEvents!.items,
        filterAddresses,
      );

      // Sort by timestamp descending (newest first)
      return latestProvenanceEventB.timestamp
          .compareTo(latestProvenanceEventA.timestamp);
    });
  }

  /// Find the latest relevant provenance event based on filter addresses.
  /// If filterAddresses is provided and contains a matching event, return it.
  /// Otherwise, return the first event in the list.
  v2.ProvenanceEvent _findLatestProvenanceEvent(
    List<v2.ProvenanceEvent> events,
    List<String>? filterAddresses,
  ) {
    if (filterAddresses == null || filterAddresses.isEmpty) {
      return events.first;
    }

    // Try to find event matching any of the filter addresses
    final normalizedAddresses =
        filterAddresses.map((e) => e.toUpperCase()).toList();

    return events.firstWhereOrNull(
          (e) =>
              normalizedAddresses.contains(e.fromAddress?.toUpperCase()) ||
              normalizedAddresses.contains(e.toAddress?.toUpperCase()),
        ) ??
        events.first;
  }
}
