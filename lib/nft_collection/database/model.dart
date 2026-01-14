import 'package:drift/drift.dart';

/// Channel table - stores DP1 channels and local virtual channels
class Channels extends Table {
  TextColumn get id => text()();
  IntColumn get type => integer()(); // 0=dp1, 1=local_virtual
  TextColumn get baseUrl => text().nullable()();
  TextColumn get slug => text().nullable()();
  TextColumn get title => text()();
  TextColumn get curator => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get coverImageUri => text().nullable()();
  IntColumn get createdAtUs => integer()();
  IntColumn get updatedAtUs => integer()();
  IntColumn get sortOrder => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Playlist table - stores DP1 playlists and address-based playlists
class Playlists extends Table {
  TextColumn get id => text()();
  TextColumn get channelId => text().nullable()();
  IntColumn get type => integer()(); // 0=dp1, 1=address_playlist
  TextColumn get baseUrl => text().nullable()();

  TextColumn get dpVersion => text().nullable()();
  TextColumn get slug => text().nullable()();
  TextColumn get title => text()();
  IntColumn get createdAtUs => integer()();
  IntColumn get updatedAtUs => integer()();

  // DP1 signatures stored as JSON array
  // v1.1.0+: array of objects
  // legacy v1.0.x: ["ed25519:<hex>"]
  TextColumn get signaturesJson => text()();
  TextColumn get defaultsJson => text().nullable()();
  TextColumn get dynamicQueriesJson => text().nullable()();

  // Address playlist fields
  TextColumn get ownerAddress => text().nullable()(); // uppercase
  TextColumn get ownerChain => text().nullable()();

  IntColumn get sortMode => integer()(); // 0=position, 1=provenance
  IntColumn get itemCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items table - stores unique playlist items (DP1 items and indexer tokens)
class Items extends Table {
  TextColumn get id => text()();
  IntColumn get kind => integer()(); // 0=dp1_item, 1=indexer_token

  // Lite UI fields (enrichment → metadata priority)
  TextColumn get title => text().nullable()();
  TextColumn get subtitle => text().nullable()(); // artists string
  TextColumn get thumbnailUri => text().nullable()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get provenanceJson => text().nullable()();

  // DP1 fields
  TextColumn get sourceUri => text().nullable()();
  TextColumn get refUri => text().nullable()();
  TextColumn get license => text().nullable()();
  TextColumn get reproJson => text().nullable()();
  TextColumn get overrideJson => text().nullable()();
  TextColumn get displayJson => text().nullable()();

  // Full token data for indexer tokens (kind=1)
  // Stores complete AssetToken JSON for reconstruction
  TextColumn get tokenDataJson => text().nullable()();

  IntColumn get updatedAtUs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// PlaylistEntries table - join table for playlist membership
/// with per-playlist ordering
class PlaylistEntries extends Table {
  TextColumn get playlistId => text()();
  TextColumn get itemId => text()();

  // Per-playlist ordering
  IntColumn get position => integer().nullable()();
  IntColumn get sortKeyUs => integer()();

  IntColumn get updatedAtUs => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, itemId};
}
