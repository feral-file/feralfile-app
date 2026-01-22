//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:io';

import 'package:autonomy_flutter/nft_collection/database/model.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'playlist_database.g.dart';

@DriftDatabase(tables: [Channels, Playlists, Items, PlaylistEntries])
class PlaylistDatabase extends _$PlaylistDatabase {
  PlaylistDatabase() : super(_openConnection());

  @override
  int get schemaVersion =>
      1; // Added tokenDataJson field for full token storage

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();

          // Create indexes via customStatement as recommended
          // Note: Drift converts camelCase to snake_case in SQL
          await customStatement(
            'CREATE INDEX idx_channels_type_order ON channels(type, sort_order)',
          );
          await customStatement(
            'CREATE INDEX idx_playlists_channel ON playlists(channel_id, type)',
          );
          await customStatement(
            'CREATE INDEX idx_playlists_owner ON playlists(type, owner_address)',
          );
          await customStatement(
            'CREATE INDEX idx_items_kind_updated ON items(kind, updated_at_us)',
          );
          await customStatement(
            'CREATE INDEX idx_entries_sort ON playlist_entries(playlist_id, sort_key_us DESC, item_id DESC)',
          );
          await customStatement(
            'CREATE INDEX idx_entries_position ON playlist_entries(playlist_id, position ASC, item_id ASC)',
          );
        },
        onUpgrade: (Migrator m, int from, int to) async {},
      );

  // ========== Channels ==========

  Future<void> upsertChannel(ChannelsCompanion channel) async {
    await into(channels).insertOnConflictUpdate(channel);
  }

  Future<void> upsertChannels(List<ChannelsCompanion> channelList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(channels, channelList);
    });
  }

  Stream<List<Channel>> watchChannels({
    int? type,
    String? baseUrl,
    int? size,
  }) {
    final query = select(channels);
    if (type != null) {
      query.where((c) => c.type.equals(type));
    }
    if (baseUrl != null) {
      query.where((c) => c.baseUrl.equals(baseUrl));
    }
    query.orderBy([
      (c) => OrderingTerm(expression: c.sortOrder, mode: OrderingMode.asc),
    ]);
    if (size != null) {
      query.limit(size);
    }
    return query.watch();
  }

  Future<Channel?> getChannelById(String channelId) async {
    return (select(channels)..where((c) => c.id.equals(channelId)))
        .getSingleOrNull();
  }

  Future<Channel?> getChannelByPlaylistId(String playlistId) async {
    final query = select(playlists).join([
      innerJoin(
        channels,
        channels.id.equalsExp(playlists.channelId),
      ),
    ])
      ..where(playlists.id.equals(playlistId));

    final result = await query.getSingleOrNull();
    if (result == null) {
      return null;
    }
    return result.readTable(channels);
  }

  /// Get ChannelReference by playlistId using a single join query
  /// Returns channel data with baseUrl extracted from the playlist
  Future<ChannelReferenceData?> getChannelReferenceDataByPlaylistId(
      String playlistId) async {
    final query = select(playlists).join([
      innerJoin(
        channels,
        channels.id.equalsExp(playlists.channelId),
      ),
    ])
      ..where(playlists.id.equals(playlistId));

    final result = await query.getSingleOrNull();
    if (result == null) {
      return null;
    }

    final channel = result.readTable(channels);
    final playlist = result.readTable(playlists);
    return ChannelReferenceData(channel: channel, baseUrl: playlist.baseUrl);
  }

  // ========== Playlists ==========

  Future<void> upsertPlaylist(PlaylistsCompanion playlist) async {
    await into(playlists).insertOnConflictUpdate(playlist);
  }

  Future<void> upsertPlaylists(List<PlaylistsCompanion> playlistList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(playlists, playlistList);
    });
  }

  Stream<List<Playlist>> watchPlaylists({
    String? channelId,
    int? type,
    int? size,
  }) {
    final query = select(playlists);
    if (channelId != null) {
      query.where((p) => p.channelId.equals(channelId));
    }
    if (type != null) {
      query.where((p) => p.type.equals(type));
    }
    query.orderBy([
      (p) => OrderingTerm(expression: p.createdAtUs, mode: OrderingMode.desc),
    ]);
    if (size != null) {
      query.limit(size);
    }
    return query.watch();
  }

  Future<Playlist?> getPlaylistById(String playlistId) async {
    return (select(playlists)..where((p) => p.id.equals(playlistId)))
        .getSingleOrNull();
  }

  // ========== Items ==========

  Future<void> upsertItem(ItemsCompanion item) async {
    await into(items).insertOnConflictUpdate(item);
  }

  Future<void> upsertItems(List<ItemsCompanion> itemList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(items, itemList);
    });
  }

  Future<Item?> getItemById(String itemId) async {
    return (select(items)..where((i) => i.id.equals(itemId))).getSingleOrNull();
  }

  // ========== PlaylistEntries ==========

  Future<void> upsertPlaylistEntry(PlaylistEntriesCompanion entry) async {
    await into(playlistEntries).insertOnConflictUpdate(entry);
  }

  Future<void> upsertPlaylistEntries(
      List<PlaylistEntriesCompanion> entryList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(playlistEntries, entryList);
    });
  }

  /// Get all playlist items for a playlist by joining Playlists, PlaylistEntries
  /// and Items.
  ///
  /// This returns a full, non-paginated list ordered according to the
  /// playlist's sort mode:
  /// - sortMode = 0 → order by position ascending
  /// - sortMode = 1 → order by provenance (sortKeyUs descending)
  Future<List<PlaylistItemLite>> getPlaylistItems(String playlistId) async {
    // Look up playlist to determine sort mode
    final playlist = await getPlaylistById(playlistId);
    final orderByProvenance =
        playlist?.sortMode == DriftPlaylistSortMode.provenance.value;

    final query = select(playlists).join([
      innerJoin(
        playlistEntries,
        playlistEntries.playlistId.equalsExp(playlists.id),
      ),
      innerJoin(
        items,
        items.id.equalsExp(playlistEntries.itemId),
      ),
    ])
      ..where(playlists.id.equals(playlistId));

    if (orderByProvenance) {
      query.orderBy([
        OrderingTerm(
          expression: playlistEntries.sortKeyUs,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(
          expression: items.id,
          mode: OrderingMode.desc,
        ),
      ]);
    } else {
      query.orderBy([
        OrderingTerm(
          expression: playlistEntries.position,
          mode: OrderingMode.asc,
        ),
        OrderingTerm(
          expression: items.id,
          mode: OrderingMode.asc,
        ),
      ]);
    }

    final rows = await query.get();
    return rows.map((row) {
      final entry = row.readTable(playlistEntries);
      final item = row.readTable(items);
      return PlaylistItemLite(
        playlistId: entry.playlistId,
        itemId: item.id,
        kind: item.kind,
        title: item.title,
        subtitle: item.subtitle,
        thumbnailUri: item.thumbnailUri,
        durationSec: item.durationSec,
        position: entry.position,
        sortKeyUs: entry.sortKeyUs,
      );
    }).toList();
  }

  /// Watch playlist items page with join (lite projection) and keyset paging
  Stream<List<PlaylistItemLite>> watchPlaylistItemsPage({
    required String playlistId,
    int limit = 10,
    int? cursorSortKeyUs,
    String? cursorItemId,
    bool orderByProvenance = true,
  }) {
    final query = select(playlistEntries).join([
      innerJoin(items, items.id.equalsExp(playlistEntries.itemId)),
    ])
      ..where(playlistEntries.playlistId.equals(playlistId))
      ..limit(limit);

    if (orderByProvenance) {
      query.orderBy([
        OrderingTerm(
          expression: playlistEntries.sortKeyUs,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(expression: items.id, mode: OrderingMode.desc),
      ]);

      // Apply keyset cursor for provenance ordering
      if (cursorSortKeyUs != null && cursorItemId != null) {
        query.where(
          (playlistEntries.sortKeyUs.isSmallerThanValue(cursorSortKeyUs)) |
              ((playlistEntries.sortKeyUs.equals(cursorSortKeyUs)) &
                  (items.id.isSmallerThanValue(cursorItemId))),
        );
      }
    } else {
      query.orderBy([
        OrderingTerm(
            expression: playlistEntries.position, mode: OrderingMode.asc),
        OrderingTerm(expression: items.id, mode: OrderingMode.asc),
      ]);

      // Apply keyset cursor for position ordering
      if (cursorSortKeyUs != null && cursorItemId != null) {
        // Note: cursorSortKeyUs is actually position in this case
        query.where(
          (playlistEntries.position.isBiggerThanValue(cursorSortKeyUs)) |
              ((playlistEntries.position.equals(cursorSortKeyUs)) &
                  (items.id.isBiggerThanValue(cursorItemId))),
        );
      }
    }

    return query.watch().map((rows) {
      return rows.map((row) {
        final entry = row.readTable(playlistEntries);
        final item = row.readTable(items);
        return PlaylistItemLite(
          playlistId: entry.playlistId,
          itemId: item.id,
          kind: item.kind,
          title: item.title,
          subtitle: item.subtitle,
          thumbnailUri: item.thumbnailUri,
          durationSec: item.durationSec,
          position: entry.position,
          sortKeyUs: entry.sortKeyUs,
        );
      }).toList();
    });
  }

  /// Count entries for a playlist
  Future<int> countPlaylistEntries(String playlistId) async {
    final query = selectOnly(playlistEntries)
      ..addColumns([playlistEntries.itemId.count()])
      ..where(playlistEntries.playlistId.equals(playlistId));
    final result = await query.getSingle();
    return result.read(playlistEntries.itemId.count()) ?? 0;
  }

  /// Delete all entries for a playlist
  Future<void> deletePlaylistEntries(String playlistId) async {
    await (delete(playlistEntries)
          ..where((e) => e.playlistId.equals(playlistId)))
        .go();
  }

  /// Clear all data
  Future<void> clearAll() async {
    await delete(playlistEntries).go();
    await delete(items).go();
    await delete(playlists).go();
    await delete(channels).go();
  }
}

/// DTO for channel reference data from joined query
/// Contains raw channel row and baseUrl to build ChannelReference
class ChannelReferenceData {
  ChannelReferenceData({required this.channel, required this.baseUrl});

  final Channel channel;
  final String? baseUrl;
}

/// Lightweight DTO for playlist item list display
class PlaylistItemLite {
  PlaylistItemLite({
    required this.playlistId,
    required this.itemId,
    required this.kind,
    this.title,
    this.subtitle,
    this.thumbnailUri,
    this.durationSec,
    this.position,
    required this.sortKeyUs,
  });

  final String playlistId;
  final String itemId;
  final int kind;
  final String? title;
  final String? subtitle;
  final String? thumbnailUri;
  final int? durationSec;
  final int? position;
  final int sortKeyUs;

  DP1Item toDP1Item() {
    return DP1Item(
      id: itemId,
      duration: durationSec ?? 0,
      title: title,
      source: thumbnailUri,
      license: ArtworkDisplayLicense.open,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'playlist_cache.sqlite'));
    log.info('[PlaylistDatabase] SQLite database location: ${file.path}');
    return NativeDatabase.createInBackground(
      file,
      setup: (database) async {
        // Allow more time when DB is locked before failing
        database.execute('PRAGMA busy_timeout = 5000');

        // Enable WAL mode for better concurrency
        database.execute('PRAGMA journal_mode = WAL');
      },
    );
  });
}
