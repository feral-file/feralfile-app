//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/database/token_to_playlist_item_transformer.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/provenance.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:drift/drift.dart' as drift;

/// Drift-backed implementation of IndexerDatabaseAbstract
/// Stores tokens as items in playlist_entries, supports reactive streams
class IndexerDatabaseDrift implements IndexerDatabaseAbstract {
  IndexerDatabaseDrift(this._playlistDb);

  final PlaylistDatabase _playlistDb;

  @override
  Future<void> insertTokens(List<v2.AssetToken> tokens) async {
    if (tokens.isEmpty) {
      log.info(
          '[IndexerDatabaseDrift] insertTokens called with 0 tokens, skipping');
      return;
    }

    log.info(
        '[IndexerDatabaseDrift] insertTokens called with ${tokens.length} tokens');

    try {
      final addressPlaylists =
          await injector<DriftDatabaseService>().getAddressPlaylistRows();
      final addresses =
          addressPlaylists.map((p) => p.ownerAddress).nonNulls.toList();

      // Transform and insert for each address playlist
      for (final address in addresses) {
        final playlistId = DP1CallExtension.generatePlaylistId(address);

        // Filter tokens to only include ones owned by this address
        final normalizedAddress = address.toUpperCase();
        final ownedTokens = tokens.where((token) {
          final owners = token.owners?.items ?? [];
          // If owners list is empty, consider checking currentOwner field as fallback
          if (owners.isEmpty && token.currentOwner != null) {
            return token.currentOwner!.toUpperCase() == normalizedAddress;
          }
          return owners.any(
              (owner) => owner.ownerAddress.toUpperCase() == normalizedAddress);
        }).toList();

        log.info(
          '[IndexerDatabaseDrift] insertTokens: address $address owns ${ownedTokens.length}/${tokens.length} tokens',
        );

        if (ownedTokens.isEmpty) {
          log.info(
            '[IndexerDatabaseDrift] insertTokens: No tokens owned by $address, skipping',
          );
          continue;
        }

        final inputs = createTransformInputs(
          tokens: ownedTokens,
          playlistId: playlistId,
          ownerAddress: address,
        );

        final results = await batchTransformTokensInIsolate(inputs);

        final itemCompanions = results.map((r) => r.itemCompanion).toList();
        final entryCompanions = results.map((r) => r.entryCompanion).toList();

        // Debug: Check if tokenDataJson is present
        final withJson = itemCompanions
            .where((c) =>
                c.tokenDataJson.present &&
                c.tokenDataJson.value != null &&
                c.tokenDataJson.value!.isNotEmpty)
            .length;
        log.info(
          '[IndexerDatabaseDrift] insertTokens: upserting ${itemCompanions.length} items ($withJson have tokenDataJson) and ${entryCompanions.length} entries for $playlistId',
        );

        await _playlistDb.upsertItems(itemCompanions);
        await _playlistDb.upsertPlaylistEntries(entryCompanions);

        // Update itemCount (only if playlist exists - should be created by bootstrap)
        final count = await _playlistDb.countPlaylistEntries(playlistId);
        final updated = await (_playlistDb.update(_playlistDb.playlists)
              ..where((p) => p.id.equals(playlistId)))
            .write(
          PlaylistsCompanion(
            itemCount: drift.Value(count),
            updatedAtUs: drift.Value(DateTime.now().microsecondsSinceEpoch),
          ),
        );

        // Log if playlist doesn't exist (should have been created by bootstrap)
        if (updated == 0) {
          log.info(
            '[IndexerDatabaseDrift] Playlist $playlistId not found for itemCount update. Bootstrap may not have run yet.',
          );
        }
      }

      log.info('[IndexerDatabaseDrift] Inserted ${tokens.length} tokens');
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error inserting tokens: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    // await _playlistDb.clearAll();
  }

  @override
  Future<void> deleteToken(String cid) async {
    // Delete from items (cascade will delete playlist_entries)
    await (_playlistDb.delete(_playlistDb.items)
          ..where((i) => i.id.equals(cid)))
        .go();
  }

  @override
  Future<void> deleteTokens(List<String> cids) async {
    if (cids.isEmpty) {
      return;
    }
    await (_playlistDb.delete(_playlistDb.items)..where((i) => i.id.isIn(cids)))
        .go();
  }

  @override
  Future<List<AddressAssetTokens>> getGroupAssetTokensByOwnersGroupByAddress({
    required List<String> owners,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  }) async {
    final groupByAddress = <AddressAssetTokens>[];
    final addressService = injector<AddressService>();

    for (final owner in owners) {
      final assetTokens = await getTokensByOwners(owners: [owner]);
      if (assetTokens.isEmpty) {
        continue;
      }

      final walletAddress = addressService.getWalletAddress(owner);
      if (walletAddress == null) {
        continue;
      }

      groupByAddress.add(
        AddressAssetTokens(
          address: walletAddress,
          assetTokens: assetTokens,
        ),
      );
    }

    return groupByAddress;
  }

  @override
  Future<List<v2.AssetToken>> getTokensByOwners({
    required List<String> owners,
  }) async {
    if (owners.isEmpty) {
      return [];
    }

    try {
      final addressService = injector<AddressService>();
      final playlistIds = <String>[];

      // Build playlist IDs for all owners
      for (final owner in owners) {
        final walletAddress = addressService.getWalletAddress(owner);
        if (walletAddress == null) continue;

        final chain = walletAddress.cryptoType == CryptoType.ETH
            ? DP1ProvenanceChain.evm.value
            : walletAddress.cryptoType == CryptoType.XTZ
                ? DP1ProvenanceChain.tezos.value
                : DP1ProvenanceChain.other.value;
        playlistIds.add('addr:$chain:$owner');
      }

      if (playlistIds.isEmpty) return [];

      // Debug: Check playlist entries count
      final entryCount =
          await _playlistDb.countPlaylistEntries(playlistIds.first);
      log.info(
        '[IndexerDatabaseDrift] getTokensByOwners: playlist ${playlistIds.first} has $entryCount entries',
      );

      // Query items via playlist_entries join
      final query = _playlistDb.select(_playlistDb.items).join([
        drift.innerJoin(
          _playlistDb.playlistEntries,
          _playlistDb.playlistEntries.itemId.equalsExp(_playlistDb.items.id),
        ),
      ])
        ..where(_playlistDb.playlistEntries.playlistId.isIn(playlistIds))
        ..orderBy([
          drift.OrderingTerm(
            expression: _playlistDb.playlistEntries.sortKeyUs,
            mode: drift.OrderingMode.desc,
          ),
        ]);

      final results = await query.get();
      log.info(
        '[IndexerDatabaseDrift] getTokensByOwners: query returned ${results.length} rows',
      );

      // Reconstruct AssetTokens from tokenDataJson
      final tokens = <v2.AssetToken>[];
      var nullJsonCount = 0;
      var parseErrorCount = 0;

      for (final row in results) {
        final item = row.readTable(_playlistDb.items);
        if (item.tokenDataJson == null || item.tokenDataJson!.isEmpty) {
          nullJsonCount++;
          continue;
        }

        try {
          final tokenMap =
              json.decode(item.tokenDataJson!) as Map<String, dynamic>;
          tokens.add(v2.AssetToken.fromRest(tokenMap));
        } catch (e) {
          parseErrorCount++;
          log.info(
            '[IndexerDatabaseDrift] Error parsing token JSON for ${item.id}: $e',
          );
        }
      }

      log.info(
        '[IndexerDatabaseDrift] getTokensByOwners: returning ${tokens.length} tokens (nullJson: $nullJsonCount, parseErrors: $parseErrorCount)',
      );
      return tokens;
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error in getTokensByOwners: $e');
      return [];
    }
  }

  @override
  Future<List<v2.AssetToken>> getTokensByCIDs({
    required List<String> cids,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  }) async {
    if (cids.isEmpty) {
      return [];
    }

    try {
      final query = _playlistDb.select(_playlistDb.items)
        ..where((item) => item.id.isIn(cids) & item.kind.equals(1));

      final items = await query.get();

      // Reconstruct AssetTokens from tokenDataJson
      final tokens = <v2.AssetToken>[];
      for (final item in items) {
        if (item.tokenDataJson != null && item.tokenDataJson!.isNotEmpty) {
          try {
            final tokenMap =
                json.decode(item.tokenDataJson!) as Map<String, dynamic>;
            tokens.add(v2.AssetToken.fromRest(tokenMap));
          } catch (e) {
            log.info(
              '[IndexerDatabaseDrift] Error parsing token JSON for ${item.id}: $e',
            );
          }
        }
      }

      return tokens;
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error in getTokensByCIDs: $e');
      return [];
    }
  }

  @override
  Future<v2.AssetToken?> findTokenByCid(String cid) async {
    try {
      final item = await (_playlistDb.select(_playlistDb.items)
            ..where((i) => i.id.equals(cid) & i.kind.equals(1)))
          .getSingleOrNull();

      if (item == null || item.tokenDataJson == null) {
        return null;
      }

      final tokenMap = json.decode(item.tokenDataJson!) as Map<String, dynamic>;
      return v2.AssetToken.fromRest(tokenMap);
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error in findTokenByCid: $e');
      return null;
    }
  }

  @override
  Future<List<v2.AssetToken>> getTokensByTokenIds({
    required List<String> tokenIds,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  }) async {
    if (tokenIds.isEmpty) {
      return [];
    }

    try {
      // tokenIds are numeric IDs, need to query by id field
      final intIds =
          tokenIds.map((id) => int.tryParse(id)).whereType<int>().toList();
      if (intIds.isEmpty) return [];

      // Note: Items table uses cid (string) as primary key, not numeric id
      // This method seems to be for querying by the token's numeric id field
      // For now, query all items and filter in memory
      final allItems = await (_playlistDb.select(_playlistDb.items)
            ..where((i) => i.kind.equals(1)))
          .get();

      final tokens = <v2.AssetToken>[];
      for (final item in allItems) {
        if (item.tokenDataJson != null && item.tokenDataJson!.isNotEmpty) {
          try {
            final tokenMap =
                json.decode(item.tokenDataJson!) as Map<String, dynamic>;
            final token = v2.AssetToken.fromRest(tokenMap);
            if (intIds.contains(token.id)) {
              tokens.add(token);
            }
          } catch (e) {
            log.info(
              '[IndexerDatabaseDrift] Error parsing token JSON for ${item.id}: $e',
            );
          }
        }
      }

      return tokens;
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error in getTokensByTokenIds: $e');
      return [];
    }
  }

  @override
  Stream<List<v2.AssetToken>> watchTokensByOwners({
    required List<String> owners,
  }) {
    if (owners.isEmpty) {
      return Stream.value([]);
    }

    try {
      final addressService = injector<AddressService>();
      final playlistIds = <String>[];

      // Build playlist IDs for all owners
      for (final owner in owners) {
        final walletAddress = addressService.getWalletAddress(owner);
        if (walletAddress == null) continue;

        final playlistId = DP1CallExtension.generatePlaylistId(owner);
        playlistIds.add(playlistId);
      }

      if (playlistIds.isEmpty) return Stream.value([]);

      // Query items via playlist_entries join
      final query = _playlistDb.select(_playlistDb.items).join([
        drift.innerJoin(
          _playlistDb.playlistEntries,
          _playlistDb.playlistEntries.itemId.equalsExp(_playlistDb.items.id),
        ),
      ])
        ..where(_playlistDb.playlistEntries.playlistId.isIn(playlistIds))
        ..orderBy([
          drift.OrderingTerm(
            expression: _playlistDb.playlistEntries.sortKeyUs,
            mode: drift.OrderingMode.desc,
          ),
        ]);

      // Watch the query and map results to AssetTokens
      return query.watch().map((results) {
        log.info(
          '[IndexerDatabaseDrift] watchTokensByOwners: received ${results.length} rows from watch stream',
        );

        final tokens = <v2.AssetToken>[];
        var nullJsonCount = 0;
        var parseErrorCount = 0;

        for (final row in results) {
          final item = row.readTable(_playlistDb.items);
          if (item.tokenDataJson == null || item.tokenDataJson!.isEmpty) {
            nullJsonCount++;
            continue;
          }

          try {
            final tokenMap =
                json.decode(item.tokenDataJson!) as Map<String, dynamic>;
            tokens.add(v2.AssetToken.fromRest(tokenMap));
          } catch (e) {
            parseErrorCount++;
            log.info(
              '[IndexerDatabaseDrift] watchTokensByOwners: Error parsing token JSON for ${item.id}: $e',
            );
          }
        }

        log.info(
          '[IndexerDatabaseDrift] watchTokensByOwners: emitting ${tokens.length} tokens (nullJson: $nullJsonCount, parseErrors: $parseErrorCount)',
        );
        return tokens;
      });
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error in watchTokensByOwners: $e');
      return Stream.value([]);
    }
  }

  @override
  Stream<List<v2.AssetToken>> watchTokensByCIDs({
    required List<String> cids,
  }) {
    if (cids.isEmpty) {
      return Stream.value([]);
    }

    try {
      final query = _playlistDb.select(_playlistDb.items)
        ..where((item) => item.id.isIn(cids) & item.kind.equals(1));

      // Watch the query and map results to AssetTokens
      return query.watch().map((items) {
        final tokens = <v2.AssetToken>[];
        for (final item in items) {
          if (item.tokenDataJson != null && item.tokenDataJson!.isNotEmpty) {
            try {
              final tokenMap =
                  json.decode(item.tokenDataJson!) as Map<String, dynamic>;
              tokens.add(v2.AssetToken.fromRest(tokenMap));
            } catch (e) {
              log.info(
                '[IndexerDatabaseDrift] Error parsing token JSON for ${item.id}: $e',
              );
            }
          }
        }
        return tokens;
      });
    } catch (e) {
      log.info('[IndexerDatabaseDrift] Error in watchTokensByCIDs: $e');
      return Stream.value([]);
    }
  }
}
