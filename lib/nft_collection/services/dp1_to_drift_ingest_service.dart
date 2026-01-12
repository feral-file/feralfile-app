//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/database/token_to_playlist_item_transformer.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart'
    as model;
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:drift/drift.dart';
import 'package:sentry/sentry.dart';

/// Service to ingest DP1 channels/playlists/items into Drift
class DP1ToDriftIngestService {
  DP1ToDriftIngestService(this._db, this._indexerService);

  final PlaylistDatabase _db;
  final NftIndexerService _indexerService;

  /// Ingest a DP1 channel
  Future<void> ingestChannel(model.Channel channel, String baseUrl) async {
    try {
      final companion = _channelToCompanion(channel, baseUrl);
      await _db.upsertChannel(companion);
      log.info('[DP1ToDriftIngestService] Ingested channel: ${channel.id}');
    } catch (e, st) {
      log.info('[DP1ToDriftIngestService] Error ingesting channel: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Ingest multiple DP1 channels
  Future<void> ingestChannels(
    List<model.Channel> channels,
    String baseUrl,
  ) async {
    try {
      final companions =
          channels.map((c) => _channelToCompanion(c, baseUrl)).toList();
      await _db.upsertChannels(companions);
      log.info(
        '[DP1ToDriftIngestService] Ingested ${channels.length} channels',
      );
    } catch (e, st) {
      log.info('[DP1ToDriftIngestService] Error ingesting channels: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Ingest a DP1 playlist with its items
  /// If the playlist has dynamic queries, fetch tokens from indexer and store them
  Future<void> ingestPlaylist(
    DP1Call playlist,
    String baseUrl,
    String? channelId,
  ) async {
    try {
      // Convert playlist
      final playlistCompanion =
          _playlistToCompanion(playlist, baseUrl, channelId);
      await _db.upsertPlaylist(playlistCompanion);

      // Handle static items (DP1 items)
      if (playlist.items.isNotEmpty) {
        final itemCompanions = <ItemsCompanion>[];
        final entryCompanions = <PlaylistEntriesCompanion>[];

        for (var i = 0; i < playlist.items.length; i++) {
          final dp1Item = playlist.items[i];
          final result = _dp1ItemToCompanions(
            dp1Item: dp1Item,
            playlistId: playlist.id,
            position: i,
          );
          itemCompanions.add(result.itemCompanion);
          entryCompanions.add(result.entryCompanion);
        }

        await _db.upsertItems(itemCompanions);
        await _db.upsertPlaylistEntries(entryCompanions);

        // Update item count for static items
        await _db.upsertPlaylist(
          playlistCompanion.copyWith(
            itemCount: Value(playlist.items.length),
          ),
        );
      }

      // Handle dynamic queries - fetch tokens from indexer
      if (playlist.dynamicQueries.isNotEmpty) {
        log.info(
          '[DP1ToDriftIngestService] Playlist ${playlist.id} has ${playlist.dynamicQueries.length} dynamic queries, fetching tokens from indexer',
        );
        
        await _resolveDynamicQueriesAndStore(playlist);
      }

      log.info(
        '[DP1ToDriftIngestService] Ingested playlist: ${playlist.id} with ${playlist.items.length} static items and ${playlist.dynamicQueries.length} dynamic queries',
      );
    } catch (e, st) {
      log.info('[DP1ToDriftIngestService] Error ingesting playlist: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Ingest multiple DP1 playlists
  Future<void> ingestPlaylists(
    List<DP1Call> playlists,
    String baseUrl,
    String? channelId,
  ) async {
    for (final playlist in playlists) {
      await ingestPlaylist(playlist, baseUrl, channelId);
    }
  }

  /// Convert Channel to Drift companion
  ChannelsCompanion _channelToCompanion(
    model.Channel channel,
    String baseUrl,
  ) {
    return ChannelsCompanion.insert(
      id: channel.id,
      type: 0, // dp1
      baseUrl: Value(baseUrl),
      slug: Value(channel.slug),
      title: channel.title,
      curator: Value(channel.curator),
      summary: Value(channel.summary),
      coverImageUri: Value(channel.coverImage),
      createdAtUs: channel.created.microsecondsSinceEpoch,
      updatedAtUs: DateTime.now().microsecondsSinceEpoch,
      sortOrder: const Value(null),
    );
  }

  /// Convert DP1Call to Drift companion
  PlaylistsCompanion _playlistToCompanion(
    DP1Call playlist,
    String baseUrl,
    String? channelId,
  ) {
    // Convert signatures to JSON array
    // DP1 v1.1.0+: signatures field (array of objects)
    // DP1 v1.0.x: signature field (single string) -> wrap as ["signature"]
    final signaturesJson = _convertSignaturesToArray(playlist);

    return PlaylistsCompanion.insert(
      id: playlist.id,
      channelId: Value(channelId),
      type: 0, // dp1
      baseUrl: Value(baseUrl),
      dpVersion: Value(playlist.dpVersion),
      slug: Value(playlist.slug),
      title: playlist.title,
      createdAtUs: playlist.created.microsecondsSinceEpoch,
      updatedAtUs: DateTime.now().microsecondsSinceEpoch,
      signaturesJson: signaturesJson,
      defaultsJson: Value(
        playlist.defaults != null ? json.encode(playlist.defaults) : null,
      ),
      dynamicQueriesJson: Value(
        playlist.dynamicQueries.isNotEmpty
            ? json.encode(
                playlist.dynamicQueries.map((q) => q.toJson()).toList())
            : null,
      ),
      ownerAddress: const Value(null),
      ownerChain: const Value(null),
      sortMode: 0, // position for DP1 playlists
      itemCount: Value(playlist.items.length),
    );
  }

  /// Convert DP1 signature to array format
  String _convertSignaturesToArray(DP1Call playlist) {
    // Check if playlist has v1.1.0+ signatures field in JSON
    final playlistJson = playlist.toJson();
    if (playlistJson['signatures'] != null) {
      // Already has signatures array, encode it
      return json.encode(playlistJson['signatures']);
    }

    // Legacy v1.0.x: wrap single signature as array
    if (playlist.signature.isNotEmpty) {
      return json.encode([playlist.signature]);
    }

    // No signature (shouldn't happen per DP1 spec, but handle gracefully)
    return json.encode([]);
  }

  /// Convert DP1Item to item + entry companions
  ({ItemsCompanion itemCompanion, PlaylistEntriesCompanion entryCompanion})
      _dp1ItemToCompanions({
    required DP1Item dp1Item,
    required String playlistId,
    required int position,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch;

    // Generate stable item ID from DP1 item
    // DP1 spec uses item.id field
    final itemId = dp1Item.id;

    // Extract lite fields from DP1 item
    final title = dp1Item.title;
    final sourceUri = dp1Item.source;
    final refUri = dp1Item.ref;
    final durationSec = dp1Item.duration;
    final license = dp1Item.license?.value;

    final itemCompanion = ItemsCompanion.insert(
      id: itemId,
      kind: 0, // dp1_item
      title: Value(title),
      subtitle: const Value(null), // DP1 items don't have subtitle
      thumbnailUri: const Value(null), // Will be populated from ref later
      durationSec: Value(durationSec),
      sourceUri: Value(sourceUri),
      refUri: Value(refUri),
      license: Value(license),
      overrideJson: const Value(null),
      updatedAtUs: now,
    );

    final entryCompanion = PlaylistEntriesCompanion.insert(
      playlistId: playlistId,
      itemId: itemId,
      position: Value(position),
      sortKeyUs: 0, // DP1 items use position, not provenance sorting
      updatedAtUs: now,
    );

    return (itemCompanion: itemCompanion, entryCompanion: entryCompanion);
  }

  /// Resolve dynamic queries and fetch tokens from indexer
  /// Store tokens as items in the database
  Future<void> _resolveDynamicQueriesAndStore(DP1Call playlist) async {
    try {
      for (final dynamicQuery in playlist.dynamicQueries) {
        final owners = dynamicQuery.params.owners;
        if (owners.isEmpty) {
          log.info(
            '[DP1ToDriftIngestService] No owners in dynamic query for playlist ${playlist.id}, skipping',
          );
          continue;
        }

        log.info(
          '[DP1ToDriftIngestService] Resolving dynamic query for playlist ${playlist.id} with owners: $owners',
        );

        // Fetch tokens from indexer for the specified owners
        final tokens = await _fetchTokensForOwners(owners);
        
        if (tokens.isEmpty) {
          log.info(
            '[DP1ToDriftIngestService] No tokens found for owners: $owners',
          );
          continue;
        }

        log.info(
          '[DP1ToDriftIngestService] Found ${tokens.length} tokens for owners: $owners',
        );

        // Store tokens as items and create playlist entries
        await _storeTokensAsItems(
          tokens: tokens,
          playlistId: playlist.id,
          ownerAddresses: owners,
        );
      }
    } catch (e, st) {
      log.info(
        '[DP1ToDriftIngestService] Error resolving dynamic queries: $e',
      );
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Fetch tokens from indexer for the specified owners
  Future<List<AssetToken>> _fetchTokensForOwners(List<String> owners) async {
    try {
      final request = QueryListTokensRequest(
        owners: owners,
        limit: 1000, // Fetch up to 1000 tokens per query
        expands: [
          ExpandField.provenanceEvents,
          ExpandField.owners,
          ExpandField.metadataMediaAsset,
          ExpandField.enrichmentSourceMediaAsset,
          ExpandField.enrichmentSource,
        ],
      );

      final tokens = await _indexerService.getNftTokens(request);
      return tokens;
    } catch (e, st) {
      log.info(
        '[DP1ToDriftIngestService] Error fetching tokens for owners: $e',
      );
      unawaited(Sentry.captureException(e, stackTrace: st));
      return [];
    }
  }

  /// Store tokens as items in the database
  /// Creates both Items and PlaylistEntries
  Future<void> _storeTokensAsItems({
    required List<AssetToken> tokens,
    required String playlistId,
    required List<String> ownerAddresses,
  }) async {
    try {
      if (tokens.isEmpty) {
        return;
      }

      final itemCompanions = <ItemsCompanion>[];
      final entryCompanions = <PlaylistEntriesCompanion>[];

      // Use the first owner address for sorting computation
      // This matches the behavior of address-based playlists
      final primaryOwner = ownerAddresses.first.toUpperCase();

      // Transform each token to item + entry companions
      for (final token in tokens) {
        final input = TokenTransformInput(
          token: token,
          playlistId: playlistId,
          ownerAddress: primaryOwner,
        );
        
        final result = transformTokenToPlaylistItem(input);
        itemCompanions.add(result.itemCompanion);
        entryCompanions.add(result.entryCompanion);
      }

      log.info(
        '[DP1ToDriftIngestService] Storing ${itemCompanions.length} tokens as items for playlist $playlistId',
      );

      // Upsert items and entries
      await _db.upsertItems(itemCompanions);
      await _db.upsertPlaylistEntries(entryCompanions);

      // Update playlist item count
      final count = await _db.countPlaylistEntries(playlistId);
      await (_db.update(_db.playlists)
            ..where((p) => p.id.equals(playlistId)))
          .write(
        PlaylistsCompanion(
          itemCount: Value(count),
          updatedAtUs: Value(DateTime.now().microsecondsSinceEpoch),
        ),
      );

      log.info(
        '[DP1ToDriftIngestService] Stored ${tokens.length} tokens for playlist $playlistId, total count: $count',
      );
    } catch (e, st) {
      log.info(
        '[DP1ToDriftIngestService] Error storing tokens as items: $e',
      );
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }
}
