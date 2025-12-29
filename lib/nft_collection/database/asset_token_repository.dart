//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/database.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/asset_token_watcher_extension.dart';
import 'package:autonomy_flutter/nft_collection/models/objectbox_entities.dart';
import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/token_extension.dart';
import 'package:sentry/sentry.dart';

/// Abstract base class for watching AssetToken changes in ObjectBox database.
abstract class AssetTokenWatcher {
  /// Watch tokens and return a stream that emits updated lists when data changes.
  Stream<List<AssetToken>> watch();
}

/// Helper function to check if two lists of AssetToken are equal.
/// Compares by CID and updatedAt to detect actual changes.
bool _areTokenListsEqual(List<AssetToken> a, List<AssetToken> b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    final tokenA = a[i];
    final tokenB = b[i];

    if (tokenA.cid != tokenB.cid) {
      return false;
    }

    // Compare updatedAt timestamps
    final updatedAtA = tokenA.updatedAt?.microsecondsSinceEpoch;
    final updatedAtB = tokenB.updatedAt?.microsecondsSinceEpoch;
    if (updatedAtA != updatedAtB) {
      return false;
    }
  }

  return true;
}

/// StreamTransformer to filter out duplicate token lists.
/// Only emits when the token list actually changes.
class _TokenListDistinctTransformer
    extends StreamTransformerBase<List<AssetToken>, List<AssetToken>> {
  @override
  Stream<List<AssetToken>> bind(Stream<List<AssetToken>> stream) {
    List<AssetToken>? lastTokens;
    return stream.where((tokens) {
      // Only emit if tokens actually changed
      if (lastTokens == null || !_areTokenListsEqual(lastTokens!, tokens)) {
        lastTokens = tokens;
        return true;
      }
      return false;
    });
  }
}

/// Watcher for tokens by CIDs (used for static playlists).
class AssetTokenCidsWatcher implements AssetTokenWatcher {
  AssetTokenCidsWatcher({required this.cids});

  final List<String> cids;

  @override
  Stream<List<AssetToken>> watch() {
    if (cids.isEmpty) {
      return Stream<List<AssetToken>>.value(<AssetToken>[]);
    }

    try {
      final tokenBox = ObjectBox.store.box<TokenObject>();
      final queryBuilder = tokenBox
          .query(TokenObject_.cid.oneOf(cids))
          .order(TokenObject_.updatedAtMicroseconds, flags: Order.descending);

      return queryBuilder
          .watch(triggerImmediately: true)
          .withBouncing(debounceDuration: Duration(seconds: 3))
          .map(
        (Query<TokenObject> q) {
          try {
            final results = q.find();
            final tokens = results.map((TokenObject e) => e.toToken()).toList();
            return tokens;
          } catch (e, s) {
            log.info(
              '[AssetTokenCidsWatcher] Error watching tokens by CIDs: $e',
            );
            unawaited(Sentry.captureException(
              'Error watching tokens by CIDs: $e',
              stackTrace: s,
            ));
            return <AssetToken>[];
          }
        },
      ).transform(_TokenListDistinctTransformer());
    } catch (e, s) {
      log.info(
        '[AssetTokenCidsWatcher] Error creating watch query for CIDs: $e',
      );
      unawaited(Sentry.captureException(
        'Error creating watch query for CIDs: $e',
        stackTrace: s,
      ));
      return Stream<List<AssetToken>>.value(<AssetToken>[]);
    }
  }
}

/// Watcher for tokens by owner addresses (used for dynamic playlists).
class AssetTokenAddressesWatcher implements AssetTokenWatcher {
  AssetTokenAddressesWatcher({required this.owners});

  final List<String> owners;

  @override
  Stream<List<AssetToken>> watch() {
    if (owners.isEmpty) {
      return Stream<List<AssetToken>>.value(<AssetToken>[]);
    }

    try {
      final tokenBox = ObjectBox.store.box<TokenObject>();

      // Build a combined condition that matches any of the owners by
      // currentOwner or by being contained in ownersJson.
      var condition = TokenObject_.currentOwner
          .equals(owners.first)
          .or(TokenObject_.ownersJson.contains(owners.first));

      for (final owner in owners.skip(1)) {
        condition = condition.or(
          TokenObject_.currentOwner.equals(owner).or(
                TokenObject_.ownersJson.contains(owner),
              ),
        );
      }

      final queryBuilder = tokenBox
          .query(condition)
          .order(TokenObject_.updatedAtMicroseconds, flags: Order.descending);

      return queryBuilder
          .watch(triggerImmediately: true)
          .withBouncing(debounceDuration: Duration(seconds: 3))
          .map(
        (Query<TokenObject> q) {
          try {
            final results = q.find();
            final tokens = results.map((TokenObject e) => e.toToken()).toList();
            // Sort by provenance to keep behavior consistent with other queries.
            try {
              tokens.sortByProvenance(filterAddresses: owners);
            } catch (e, s) {
              log.info(
                '[AssetTokenAddressesWatcher] Error sorting tokens by provenance: $e',
              );
              unawaited(Sentry.captureException(
                'Error sorting tokens by provenance: $e',
                stackTrace: s,
              ));
            }
            return tokens;
          } catch (e, s) {
            log.info(
              '[AssetTokenAddressesWatcher] Error watching tokens by owners: $e',
            );
            unawaited(Sentry.captureException(
              'Error watching tokens by owners: $e',
              stackTrace: s,
            ));
            return <AssetToken>[];
          }
        },
      ).transform(_TokenListDistinctTransformer());
    } catch (e, s) {
      log.info(
        '[AssetTokenAddressesWatcher] Error creating watch query for owners: $e',
      );
      unawaited(Sentry.captureException(
        'Error creating watch query for owners: $e',
        stackTrace: s,
      ));
      return Stream<List<AssetToken>>.value(<AssetToken>[]);
    }
  }
}
