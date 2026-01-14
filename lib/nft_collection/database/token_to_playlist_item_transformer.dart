//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';
import 'dart:isolate';

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:drift/drift.dart';

/// Result of transforming a token into database rows
class TokenTransformResult {
  TokenTransformResult({
    required this.itemCompanion,
    required this.entryCompanion,
  });

  final ItemsCompanion itemCompanion;
  final PlaylistEntriesCompanion entryCompanion;
}

/// Input for token transformation in isolate
class TokenTransformInput {
  TokenTransformInput({
    required this.token,
    required this.playlistId,
    required this.ownerAddress,
  });

  final AssetToken token;
  final String playlistId;
  final String ownerAddress; // Normalized uppercase
}

/// Transform AssetToken to lite item + playlist entry
/// Preserves enrichment → metadata priority using existing AssetToken ext
TokenTransformResult transformTokenToPlaylistItem(TokenTransformInput input) {
  final token = input.token;
  final playlistId = input.playlistId;
  final ownerAddress = input.ownerAddress.toUpperCase();

  // Compute sortKeyUs: latest relevant provenance timestamp for this owner
  final sortKeyUs = _computeSortKeyForOwner(token, ownerAddress);

  // Extract lite fields using existing priority (enrichment → metadata)
  final title = token.displayTitle; // enrichmentSource.name → metadata.name
  final artists =
      token.getArtists; // enrichmentSource.artists → metadata.artists
  final subtitle = artists.map((a) => a.name).join(', ');
  final thumbnailUri = token.getGalleryThumbnailUrl(
    size: 'xs',
  ); // enrichmentSource media variants → metadata variants

  final now = DateTime.now().microsecondsSinceEpoch;

  // Serialize full token to JSON for reconstruction
  final tokenMap = <String, dynamic>{
    'id': token.id.toString(),
    'cid': token.cid,
    'chain': token.chain,
    'standard': token.standard,
    'contract_address': token.contractAddress,
    'token_number': token.tokenNumber,
    if (token.currentOwner != null) 'current_owner': token.currentOwner,
    if (token.updatedAt != null)
      'updated_at': token.updatedAt!.toIso8601String(),
    if (token.metadata != null) 'metadata': token.metadata!.toJson(),
    if (token.owners != null) 'owners': token.owners!.toJson(),
    if (token.provenanceEvents != null)
      'provenance_events': token.provenanceEvents!.toJson(),
    if (token.enrichmentSource != null)
      'enrichment_source': token.enrichmentSource!.toJson(),
    if (token.metadataMediaAssets != null)
      'metadata_media_assets':
          token.metadataMediaAssets!.map((e) => e.toJson()).toList(),
    if (token.enrichmentSourceMediaAssets != null)
      'enrichment_source_media_assets':
          token.enrichmentSourceMediaAssets!.map((e) => e.toJson()).toList(),
  };
  final tokenJson = json.encode(tokenMap);

  // Create item companion (unique)
  final itemCompanion = ItemsCompanion.insert(
    id: token.cid,
    kind: DriftItemKind.indexerToken.value,
    title: Value(title),
    subtitle: Value(subtitle.isEmpty ? null : subtitle),
    thumbnailUri: Value(thumbnailUri),
    durationSec: const Value(null), // tokens don't have duration
    sourceUri: const Value(null),
    refUri: const Value(null),
    license: const Value(null),
    overrideJson: const Value(null),
    tokenDataJson: Value(tokenJson), // Store full token for reconstruction
    updatedAtUs: token.updatedAt?.microsecondsSinceEpoch ?? now,
  );

  // Create playlist entry companion (per-playlist)
  final entryCompanion = PlaylistEntriesCompanion.insert(
    playlistId: playlistId,
    itemId: token.cid,
    position: const Value(null), // No fixed position for address playlists
    sortKeyUs: sortKeyUs,
    updatedAtUs: now,
  );

  return TokenTransformResult(
    itemCompanion: itemCompanion,
    entryCompanion: entryCompanion,
  );
}

/// Compute sortKeyUs for a token based on owner address
/// Same logic as sortByProvenance(filterAddresses: [owner])
int _computeSortKeyForOwner(AssetToken token, String normalizedOwner) {
  final events = token.provenanceEvents?.items;
  if (events == null || events.isEmpty) {
    return 0; // Tokens without provenance go last
  }

  // Find latest event where owner is involved (from or to)
  int? latestRelevantTs;
  for (final event in events) {
    final fromAddress = event.fromAddress?.toUpperCase();
    final toAddress = event.toAddress?.toUpperCase();

    if (fromAddress == normalizedOwner || toAddress == normalizedOwner) {
      final eventTs = event.timestamp.microsecondsSinceEpoch;
      if (latestRelevantTs == null || eventTs > latestRelevantTs) {
        latestRelevantTs = eventTs;
      }
    }
  }

  // If no relevant event found, fallback to overall latest provenance
  if (latestRelevantTs == null && events.isNotEmpty) {
    latestRelevantTs = events
        .map((e) => e.timestamp.microsecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);
  }

  return latestRelevantTs ?? 0;
}

/// Batch transform tokens in isolate for better performance
Future<List<TokenTransformResult>> batchTransformTokensInIsolate(
  List<TokenTransformInput> inputs,
) async {
  if (inputs.length <= 10) {
    // Small batch, compute directly
    return inputs.map(transformTokenToPlaylistItem).toList();
  }

  // Large batch, use isolate
  return Isolate.run(() {
    return inputs.map(transformTokenToPlaylistItem).toList();
  });
}

/// Helper to create transform inputs from tokens
List<TokenTransformInput> createTransformInputs({
  required List<AssetToken> tokens,
  required String playlistId,
  required String ownerAddress,
}) {
  return tokens
      .map((token) => TokenTransformInput(
            token: token,
            playlistId: playlistId,
            ownerAddress: ownerAddress,
          ))
      .toList();
}
