//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

/// Helper utilities for building MeiliSearch index queries.
class IndexSearchQueryHelper {
  const IndexSearchQueryHelper._();

  /// Build filter expression for `nft_tokens` index based on owner addresses.
  ///
  /// Each address will be turned into a condition:
  /// `owner_addresses = <address>`
  /// and all conditions will be OR'ed together:
  /// `owner_addresses = addr1 OR owner_addresses = addr2 ...`
  ///
  /// Returns `null` if [addresses] is empty.
  static String? buildNftTokensOwnerFilter(List<String> addresses) {
    if (addresses.isEmpty) {
      // Return a condition that matches no addresses
      return 'owner_addresses = -';
    }

    final conditions = addresses
        .where((address) => address.trim().isNotEmpty)
        .map((address) => 'owner_addresses = $address')
        .toList();

    if (conditions.isEmpty) {
      return null;
    }

    return conditions.join(' OR ');
  }
}
