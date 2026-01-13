//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/database/token_to_playlist_item_transformer.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart'
    as model;
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:drift/drift.dart';
import 'package:sentry/sentry.dart';

/// Kind of playlist row stored in Drift.
///
/// This is mapped to the `type` column in the `Playlists` table:
/// - 0: DP1 playlist fetched from feed servers
/// - 1: Address-based playlist under `my_collection` channel.
enum DriftPlaylistKind {
  dp1(0),
  address(1);

  const DriftPlaylistKind(this.value);
  final int value;
}

/// Kind of channel row stored in Drift.
///
/// This is mapped to the `type` column in the `Channels` table:
/// - 0: DP1 channel from feed servers
/// - 1: Local virtual channel (e.g. `my_collection`).
enum DriftChannelKind {
  dp1(0),
  localVirtual(1);

  const DriftChannelKind(this.value);
  final int value;
}

/// Abstract base class for Drift database service.
///
/// Defines the interface for accessing and ingesting data into the Drift
/// [PlaylistDatabase]. Implementations should handle all database operations
/// and DP1 data ingestion.
abstract class DriftDatabaseServiceAbstract {
  // ========= Channels (raw Drift rows) =========

  /// Get channels filtered by [kind] and/or [baseUrl].
  ///
  /// When [kind] is null, all channel types are returned.
  /// When [baseUrl] is provided, only channels with that baseUrl are returned.
  Future<List<Channel>> getChannels({
    DriftChannelKind? kind,
    String? baseUrl,
  });

  Future<Channel?> getChannelById(String id);

  Future<Channel?> getMyCollectionChannel();

  // ========= Playlists (raw Drift rows) =========

  /// Get playlists filtered by channel, kind and/or baseUrl.
  ///
  /// - [channelId] null means any channel.
  /// - [kind] filters by playlist type (dp1 vs address).
  /// - [baseUrl] allows scoping DP1 playlists to a specific feed server.
  Future<List<Playlist>> getPlaylistRows({
    String? channelId,
    DriftPlaylistKind? kind,
    String? baseUrl,
  });

  Future<Playlist?> getPlaylistRowById(String id);

  /// Convenience helper to fetch all address playlists (collection playlists)
  /// under the `my_collection` virtual channel as raw Drift rows.
  Future<List<Playlist>> getAddressPlaylistRows();

  // ========= Address playlists as DP1Call =========

  /// Get all address playlists as [DP1Call] models.
  ///
  /// These are derived from Drift rows and use a dynamic query that points
  /// to the indexer GraphQL endpoint with the owner address as filter.
  Future<List<DP1Call>> getAddressPlaylistsAsDp1Calls();

  /// Get a single address playlist by its playlist id (`addr:<chain>:<address>`)
  /// as a [DP1Call] model.
  Future<DP1Call?> getAddressPlaylistAsDp1Call(String id);

  // ========= Mapping helpers =========

  /// Convert a Drift [Channel] row into the public [model.Channel] model.
  ///
  /// This is a helper that other layers can use when they need a full
  /// channel model from a Drift row.
  model.Channel channelRowToModel(Channel row);

  // ========= DP1 Ingest Methods =========

  /// Ingest a DP1 channel from a [ChannelReference].
  ///
  /// The reference contains both the channel model and its feed URL.
  Future<void> ingestChannel(ChannelReference channelRef);

  /// Ingest multiple DP1 channels
  Future<void> ingestChannels(List<ChannelReference> channels);

  /// Ingest a DP1 playlist with its items
  /// If the playlist has dynamic queries, fetch tokens from indexer and store them
  Future<void> ingestPlaylist(
    PlaylistReference playlistRef,
    String? channelId,
  );

  /// Ingest multiple DP1 playlists
  Future<void> ingestPlaylists(
    List<PlaylistReference> playlistRefs,
    String? channelId,
  );

  /// Delete all playlists of a specific kind and baseUrl
  Future<void> deleteAllPlaylists({
    required DriftPlaylistKind kind,
    required String baseUrl,
  });

  /// Delete all channels of a specific kind and baseUrl
  Future<void> deleteAllChannels({
    required DriftChannelKind kind,
    required String baseUrl,
  });
}

/// Service that encapsulates all access to the Drift [PlaylistDatabase].
///
/// Other layers (feed services, managers, blocs) should depend on this
/// service instead of talking to Drift directly.
///
/// This service also handles ingesting DP1 channels/playlists/items into Drift.
class DriftDatabaseService extends DriftDatabaseServiceAbstract {
  DriftDatabaseService(this._db, this._indexerService);

  final PlaylistDatabase _db;
  final NftIndexerService _indexerService;

  // ========= Channels (raw Drift rows) =========

  /// Get channels filtered by [kind] and/or [baseUrl].
  ///
  /// When [kind] is null, all channel types are returned.
  /// When [baseUrl] is provided, only channels with that baseUrl are returned.
  @override
  Future<List<Channel>> getChannels({
    DriftChannelKind? kind,
    String? baseUrl,
  }) async {
    final typeFilter = switch (kind) {
      DriftChannelKind.dp1 => 0,
      DriftChannelKind.localVirtual => 1,
      null => null,
    };

    // Use watch + first to reuse the existing typed query.
    final stream = _db.watchChannels(
      type: typeFilter,
      baseUrl: baseUrl,
    );
    return stream.first;
  }

  @override
  Future<Channel?> getChannelById(String id) => _db.getChannelById(id);

  @override
  Future<Channel?> getMyCollectionChannel() => getChannelById('my_collection');

  // ========= Playlists (raw Drift rows) =========

  /// Get playlists filtered by channel, kind and/or baseUrl.
  ///
  /// - [channelId] null means any channel.
  /// - [kind] filters by playlist type (dp1 vs address).
  /// - [baseUrl] allows scoping DP1 playlists to a specific feed server.
  @override
  Future<List<Playlist>> getPlaylistRows({
    String? channelId,
    DriftPlaylistKind? kind,
    String? baseUrl,
  }) async {
    final typeFilter = switch (kind) {
      DriftPlaylistKind.dp1 => 0,
      DriftPlaylistKind.address => 1,
      null => null,
    };

    final stream = _db.watchPlaylists(
      channelId: channelId,
      type: typeFilter,
    );
    final rows = await stream.first;
    if (baseUrl == null) {
      return rows;
    }
    return rows.where((p) => p.baseUrl == baseUrl).toList();
  }

  @override
  Future<Playlist?> getPlaylistRowById(String id) => _db.getPlaylistById(id);

  /// Convenience helper to fetch all address playlists (collection playlists)
  /// under the `my_collection` virtual channel as raw Drift rows.
  @override
  Future<List<Playlist>> getAddressPlaylistRows() => getPlaylistRows(
        channelId: 'my_collection',
        kind: DriftPlaylistKind.address,
      );

  // ========= Address playlists as DP1Call =========

  /// Get all address playlists as [DP1Call] models.
  ///
  /// These are derived from Drift rows and use a dynamic query that points
  /// to the indexer GraphQL endpoint with the owner address as filter.
  @override
  Future<List<DP1Call>> getAddressPlaylistsAsDp1Calls() async {
    final rows = await getAddressPlaylistRows();
    return rows.map(_addressPlaylistRowToModel).toList();
  }

  /// Get a single address playlist by its playlist id (`addr:<chain>:<address>`)
  /// as a [DP1Call] model.
  @override
  Future<DP1Call?> getAddressPlaylistAsDp1Call(String id) async {
    final row = await getPlaylistRowById(id);
    if (row == null || row.type != 1) {
      return null;
    }
    return _addressPlaylistRowToModel(row);
  }

  // ========= Mapping helpers =========

  /// Convert a Drift [Playlist] row (address playlist) into a [DP1Call] model.
  ///
  /// This mirrors the semantics of a DP1 dynamic playlist created from owners,
  /// using the `ownerAddress` column to build the dynamic query.
  DP1Call _addressPlaylistRowToModel(Playlist row) {
    final owner = row.ownerAddress ?? '';
    final owners = owner.isEmpty ? <String>[] : <String>[owner];

    return DP1Call(
      dpVersion: row.dpVersion ?? '1.0.0',
      id: row.id,
      slug: row.slug ?? '',
      title: row.title,
      created: DateTime.fromMicrosecondsSinceEpoch(row.createdAtUs),
      defaults: null,
      // Items are provided by the indexer / playlist_entries join, not DP1.
      items: const [],
      dynamicQueries: owners.isEmpty
          ? const []
          : [
              DynamicQuery(
                endpoint: '${Environment.indexerURL}/graphql',
                params: DynamicQueryParams(owners: owners),
              ),
            ],
      // Address playlists don't have DP1 signatures.
      signature: '',
    );
  }

  /// Convert a Drift [Channel] row into the public [model.Channel] model.
  ///
  /// This is a helper that other layers can use when they need a full
  /// channel model from a Drift row.
  @override
  model.Channel channelRowToModel(Channel row) {
    return model.Channel(
      id: row.id,
      slug: row.slug ?? '',
      title: row.title,
      curator: row.curator,
      summary: row.summary,
      playlists: const [],
      created: DateTime.fromMicrosecondsSinceEpoch(row.createdAtUs),
      coverImage: row.coverImageUri,
    );
  }

  // ========= DP1 Ingest Methods =========

  /// Ingest a DP1 channel from a [ChannelReference].
  ///
  /// The reference contains both the channel model and its feed URL.
  @override
  Future<void> ingestChannel(ChannelReference channelRef) async {
    final channel = channelRef.channel;
    final baseUrl = channelRef.url;
    try {
      final companion = _channelToCompanion(channel, baseUrl);
      await _db.upsertChannel(companion);
      log.info('[DriftDatabaseService] Ingested channel: ${channel.id}');
    } catch (e, st) {
      log.info('[DriftDatabaseService] Error ingesting channel: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Ingest multiple DP1 channels
  @override
  Future<void> ingestChannels(
    List<ChannelReference> channels,
  ) async {
    try {
      final companions = channels
          .map(
            (c) => _channelToCompanion(c.channel, c.url),
          )
          .toList();
      await _db.upsertChannels(companions);
      log.info(
        '[DriftDatabaseService] Ingested ${channels.length} channels: ${channels.map((c) => c.channel.title).join(', ')}',
      );
    } catch (e, st) {
      log.info('[DriftDatabaseService] Error ingesting channels: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Ingest a DP1 playlist with its items
  /// If the playlist has dynamic queries, fetch tokens from indexer and store them
  @override
  Future<void> ingestPlaylist(
    PlaylistReference playlistRef,
    String? channelId,
  ) async {
    try {
      final playlist = playlistRef.playlist;
      final baseUrl = playlistRef.url;
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
          '[DriftDatabaseService] Playlist ${playlist.id} has ${playlist.dynamicQueries.length} dynamic queries, fetching tokens from indexer',
        );

        await _resolveDynamicQueriesAndStore(playlist);
      }

      log.info(
        '[DriftDatabaseService] Ingested playlist: ${playlist.id} with ${playlist.items.length} static items and ${playlist.dynamicQueries.length} dynamic queries',
      );
    } catch (e, st) {
      log.info('[DriftDatabaseService] Error ingesting playlist: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  /// Ingest multiple DP1 playlists
  @override
  Future<void> ingestPlaylists(
    List<PlaylistReference> playlistRefs,
    String? channelId,
  ) async {
    for (final playlistRef in playlistRefs) {
      await ingestPlaylist(playlistRef, channelId);
    }
  }

  // ========= Private Ingest Helpers =========

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
            ? json
                .encode(playlist.dynamicQueries.map((q) => q.toJson()).toList())
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
            '[DriftDatabaseService] No owners in dynamic query for playlist ${playlist.id}, skipping',
          );
          continue;
        }

        log.info(
          '[DriftDatabaseService] Resolving dynamic query for playlist ${playlist.id} with owners: $owners',
        );

        // Fetch tokens from indexer for the specified owners
        final tokens = await _fetchTokensForOwners(owners);

        if (tokens.isEmpty) {
          log.info(
            '[DriftDatabaseService] No tokens found for owners: $owners',
          );
          continue;
        }

        log.info(
          '[DriftDatabaseService] Found ${tokens.length} tokens for owners: $owners',
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
        '[DriftDatabaseService] Error resolving dynamic queries: $e',
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
        '[DriftDatabaseService] Error fetching tokens for owners: $e',
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
        '[DriftDatabaseService] Storing ${itemCompanions.length} tokens as items for playlist $playlistId',
      );

      // Upsert items and entries
      await _db.upsertItems(itemCompanions);
      await _db.upsertPlaylistEntries(entryCompanions);

      // Update playlist item count
      final count = await _db.countPlaylistEntries(playlistId);
      await (_db.update(_db.playlists)..where((p) => p.id.equals(playlistId)))
          .write(
        PlaylistsCompanion(
          itemCount: Value(count),
          updatedAtUs: Value(DateTime.now().microsecondsSinceEpoch),
        ),
      );

      log.info(
        '[DriftDatabaseService] Stored ${tokens.length} tokens for playlist $playlistId, total count: $count',
      );
    } catch (e, st) {
      log.info(
        '[DriftDatabaseService] Error storing tokens as items: $e',
      );
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  @override
  Future<void> deleteAllPlaylists({
    required DriftPlaylistKind kind,
    required String baseUrl,
  }) async {
    final typeFilter = switch (kind) {
      DriftPlaylistKind.dp1 => 0,
      DriftPlaylistKind.address => 1,
    };
    final deleteQuery = _db.delete(_db.playlists)
      ..where((p) => p.type.equals(typeFilter))
      ..where((p) => p.baseUrl.equals(baseUrl));
    await deleteQuery.go();
  }

  @override
  Future<void> deleteAllChannels({
    required DriftChannelKind kind,
    required String baseUrl,
  }) async {
    final typeFilter = switch (kind) {
      DriftChannelKind.dp1 => 0,
      DriftChannelKind.localVirtual => 1,
    };

    final deleteQuery = _db.delete(_db.channels)
      ..where((c) => c.type.equals(typeFilter))
      ..where((c) => c.baseUrl.equals(baseUrl));
    await deleteQuery.go();
  }
}
