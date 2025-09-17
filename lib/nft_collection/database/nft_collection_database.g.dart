// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nft_collection_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

// ignore: avoid_classes_with_only_static_members
class $FloorNftCollectionDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$NftCollectionDatabaseBuilder databaseBuilder(String name) =>
      _$NftCollectionDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$NftCollectionDatabaseBuilder inMemoryDatabaseBuilder() =>
      _$NftCollectionDatabaseBuilder(null);
}

class _$NftCollectionDatabaseBuilder {
  _$NftCollectionDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  /// Adds migrations to the builder.
  _$NftCollectionDatabaseBuilder addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  /// Adds a database [Callback] to the builder.
  _$NftCollectionDatabaseBuilder addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  /// Creates the database and initializes it.
  Future<NftCollectionDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$NftCollectionDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$NftCollectionDatabase extends NftCollectionDatabase {
  _$NftCollectionDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  TokenDao? _tokenDaoInstance;

  AssetDao? _assetDaoInstance;

  ProvenanceDao? _provenanceDaoInstance;

  AddressCollectionDao? _addressCollectionDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 5,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Token` (`id` TEXT NOT NULL, `tokenId` TEXT, `blockchain` TEXT NOT NULL, `fungible` INTEGER, `contractType` TEXT, `contractAddress` TEXT, `edition` INTEGER NOT NULL, `editionName` TEXT, `mintedAt` INTEGER, `balance` INTEGER, `owner` TEXT NOT NULL, `owners` TEXT NOT NULL, `source` TEXT, `swapped` INTEGER, `burned` INTEGER, `lastActivityTime` INTEGER NOT NULL, `lastRefreshedTime` INTEGER NOT NULL, `ipfsPinned` INTEGER, `pending` INTEGER, `isDebugged` INTEGER, `initialSaleModel` TEXT, `originTokenInfoId` TEXT, `indexID` TEXT, PRIMARY KEY (`id`, `owner`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Asset` (`indexID` TEXT, `thumbnailID` TEXT, `lastRefreshedTime` INTEGER, `artistID` TEXT, `artistName` TEXT, `artistURL` TEXT, `artists` TEXT, `assetID` TEXT, `title` TEXT, `description` TEXT, `mimeType` TEXT, `medium` TEXT, `maxEdition` INTEGER, `source` TEXT, `sourceURL` TEXT, `previewURL` TEXT, `thumbnailURL` TEXT, `galleryThumbnailURL` TEXT, `assetData` TEXT, `assetURL` TEXT, `isFeralfileFrame` INTEGER, `initialSaleModel` TEXT, `originalFileURL` TEXT, `artworkMetadata` TEXT, PRIMARY KEY (`indexID`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Provenance` (`id` TEXT NOT NULL, `txID` TEXT NOT NULL, `type` TEXT NOT NULL, `blockchain` TEXT NOT NULL, `owner` TEXT NOT NULL, `timestamp` INTEGER NOT NULL, `txURL` TEXT NOT NULL, `tokenID` TEXT NOT NULL, `blockNumber` INTEGER, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `AddressCollection` (`address` TEXT NOT NULL, `lastRefreshedTime` INTEGER NOT NULL, `isHidden` INTEGER NOT NULL, PRIMARY KEY (`address`))');
        await database.execute(
            'CREATE INDEX `index_Token_lastActivityTime_id` ON `Token` (`lastActivityTime`, `id`)');
        await database.execute(
            'CREATE INDEX `index_Provenance_id` ON `Provenance` (`id`)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  TokenDao get tokenDao {
    return _tokenDaoInstance ??= _$TokenDao(database, changeListener);
  }

  @override
  AssetDao get assetDao {
    return _assetDaoInstance ??= _$AssetDao(database, changeListener);
  }

  @override
  ProvenanceDao get provenanceDao {
    return _provenanceDaoInstance ??= _$ProvenanceDao(database, changeListener);
  }

  @override
  AddressCollectionDao get addressCollectionDao {
    return _addressCollectionDaoInstance ??=
        _$AddressCollectionDao(database, changeListener);
  }
}

class _$TokenDao extends TokenDao {
  _$TokenDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _tokenInsertionAdapter = InsertionAdapter(
            database,
            'Token',
            (Token item) => <String, Object?>{
                  'id': item.id,
                  'tokenId': item.tokenId,
                  'blockchain': item.blockchain,
                  'fungible':
                      item.fungible == null ? null : (item.fungible! ? 1 : 0),
                  'contractType': item.contractType,
                  'contractAddress': item.contractAddress,
                  'edition': item.edition,
                  'editionName': item.editionName,
                  'mintedAt': _nullableDateTimeConverter.encode(item.mintedAt),
                  'balance': item.balance,
                  'owner': item.owner,
                  'owners': _tokenOwnersConverter.encode(item.owners),
                  'source': item.source,
                  'swapped':
                      item.swapped == null ? null : (item.swapped! ? 1 : 0),
                  'burned': item.burned == null ? null : (item.burned! ? 1 : 0),
                  'lastActivityTime':
                      _dateTimeConverter.encode(item.lastActivityTime),
                  'lastRefreshedTime':
                      _dateTimeConverter.encode(item.lastRefreshedTime),
                  'ipfsPinned': item.ipfsPinned == null
                      ? null
                      : (item.ipfsPinned! ? 1 : 0),
                  'pending':
                      item.pending == null ? null : (item.pending! ? 1 : 0),
                  'isDebugged': item.isDebugged == null
                      ? null
                      : (item.isDebugged! ? 1 : 0),
                  'initialSaleModel': item.initialSaleModel,
                  'originTokenInfoId': item.originTokenInfoId,
                  'indexID': item.indexID
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Token> _tokenInsertionAdapter;

  @override
  Future<List<String>> findAllTokenIDs() async {
    return _queryAdapter.queryList('SELECT id FROM Token',
        mapper: (Map<String, Object?> row) => row.values.first as String);
  }

  @override
  Future<List<String>> findTokenIDsByOwners(List<String> owners) async {
    const offset = 1;
    final _sqliteVariablesForOwners =
        Iterable<String>.generate(owners.length, (i) => '?${i + offset}')
            .join(',');
    return _queryAdapter.queryList(
        'SELECT id FROM Token where owner IN (' +
            _sqliteVariablesForOwners +
            ')',
        mapper: (Map<String, Object?> row) => row.values.first as String,
        arguments: [...owners]);
  }

  @override
  Future<List<String>> findTokenIDsOwnersOwn(List<String> owners) async {
    const offset = 1;
    final _sqliteVariablesForOwners =
        Iterable<String>.generate(owners.length, (i) => '?${i + offset}')
            .join(',');
    return _queryAdapter.queryList(
        'SELECT id FROM Token where owner IN (' +
            _sqliteVariablesForOwners +
            ') AND balance > 0',
        mapper: (Map<String, Object?> row) => row.values.first as String,
        arguments: [...owners]);
  }

  @override
  Future<List<Token>> findAllPendingTokens() async {
    return _queryAdapter.queryList('SELECT * FROM Token WHERE pending = 1',
        mapper: (Map<String, Object?> row) => Token(
            id: row['id'] as String,
            tokenId: row['tokenId'] as String?,
            blockchain: row['blockchain'] as String,
            fungible:
                row['fungible'] == null ? null : (row['fungible'] as int) != 0,
            contractType: row['contractType'] as String?,
            contractAddress: row['contractAddress'] as String?,
            edition: row['edition'] as int,
            editionName: row['editionName'] as String?,
            mintedAt:
                _nullableDateTimeConverter.decode(row['mintedAt'] as int?),
            balance: row['balance'] as int?,
            owner: row['owner'] as String,
            owners: _tokenOwnersConverter.decode(row['owners'] as String),
            source: row['source'] as String?,
            swapped:
                row['swapped'] == null ? null : (row['swapped'] as int) != 0,
            burned: row['burned'] == null ? null : (row['burned'] as int) != 0,
            lastActivityTime:
                _dateTimeConverter.decode(row['lastActivityTime'] as int),
            lastRefreshedTime:
                _dateTimeConverter.decode(row['lastRefreshedTime'] as int),
            ipfsPinned: row['ipfsPinned'] == null
                ? null
                : (row['ipfsPinned'] as int) != 0,
            pending:
                row['pending'] == null ? null : (row['pending'] as int) != 0,
            initialSaleModel: row['initialSaleModel'] as String?,
            originTokenInfoId: row['originTokenInfoId'] as String?,
            indexID: row['indexID'] as String?,
            isDebugged: row['isDebugged'] == null
                ? null
                : (row['isDebugged'] as int) != 0));
  }

  @override
  Future<List<Token>> findTokensByID(String id) async {
    return _queryAdapter.queryList('SELECT * FROM Token WHERE id = (?1)',
        mapper: (Map<String, Object?> row) => Token(
            id: row['id'] as String,
            tokenId: row['tokenId'] as String?,
            blockchain: row['blockchain'] as String,
            fungible:
                row['fungible'] == null ? null : (row['fungible'] as int) != 0,
            contractType: row['contractType'] as String?,
            contractAddress: row['contractAddress'] as String?,
            edition: row['edition'] as int,
            editionName: row['editionName'] as String?,
            mintedAt:
                _nullableDateTimeConverter.decode(row['mintedAt'] as int?),
            balance: row['balance'] as int?,
            owner: row['owner'] as String,
            owners: _tokenOwnersConverter.decode(row['owners'] as String),
            source: row['source'] as String?,
            swapped:
                row['swapped'] == null ? null : (row['swapped'] as int) != 0,
            burned: row['burned'] == null ? null : (row['burned'] as int) != 0,
            lastActivityTime:
                _dateTimeConverter.decode(row['lastActivityTime'] as int),
            lastRefreshedTime:
                _dateTimeConverter.decode(row['lastRefreshedTime'] as int),
            ipfsPinned: row['ipfsPinned'] == null
                ? null
                : (row['ipfsPinned'] as int) != 0,
            pending:
                row['pending'] == null ? null : (row['pending'] as int) != 0,
            initialSaleModel: row['initialSaleModel'] as String?,
            originTokenInfoId: row['originTokenInfoId'] as String?,
            indexID: row['indexID'] as String?,
            isDebugged: row['isDebugged'] == null
                ? null
                : (row['isDebugged'] as int) != 0),
        arguments: [id]);
  }

  @override
  Future<void> deleteTokens(List<String> ids) async {
    const offset = 1;
    final _sqliteVariablesForIds =
        Iterable<String>.generate(ids.length, (i) => '?${i + offset}')
            .join(',');
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Token WHERE id IN (' + _sqliteVariablesForIds + ')',
        arguments: [...ids]);
  }

  @override
  Future<void> deleteTokenByID(String id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM Token WHERE id = (?1)', arguments: [id]);
  }

  @override
  Future<void> deleteTokensByOwners(List<String> owners) async {
    const offset = 1;
    final _sqliteVariablesForOwners =
        Iterable<String>.generate(owners.length, (i) => '?${i + offset}')
            .join(',');
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Token WHERE owner IN (' + _sqliteVariablesForOwners + ')',
        arguments: [...owners]);
  }

  @override
  Future<void> removeAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM Token');
  }

  @override
  Future<void> insertTokens(List<Token> assets) async {
    await _tokenInsertionAdapter.insertList(assets, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertTokensAbort(List<Token> assets) async {
    await _tokenInsertionAdapter.insertList(assets, OnConflictStrategy.ignore);
  }
}

class _$AssetDao extends AssetDao {
  _$AssetDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _assetInsertionAdapter = InsertionAdapter(
            database,
            'Asset',
            (Asset item) => <String, Object?>{
                  'indexID': item.indexID,
                  'thumbnailID': item.thumbnailID,
                  'lastRefreshedTime':
                      _nullableDateTimeConverter.encode(item.lastRefreshedTime),
                  'artistID': item.artistID,
                  'artistName': item.artistName,
                  'artistURL': item.artistURL,
                  'artists': item.artists,
                  'assetID': item.assetID,
                  'title': item.title,
                  'description': item.description,
                  'mimeType': item.mimeType,
                  'medium': item.medium,
                  'maxEdition': item.maxEdition,
                  'source': item.source,
                  'sourceURL': item.sourceURL,
                  'previewURL': item.previewURL,
                  'thumbnailURL': item.thumbnailURL,
                  'galleryThumbnailURL': item.galleryThumbnailURL,
                  'assetData': item.assetData,
                  'assetURL': item.assetURL,
                  'isFeralfileFrame': item.isFeralfileFrame == null
                      ? null
                      : (item.isFeralfileFrame! ? 1 : 0),
                  'initialSaleModel': item.initialSaleModel,
                  'originalFileURL': item.originalFileURL,
                  'artworkMetadata': item.artworkMetadata
                }),
        _assetUpdateAdapter = UpdateAdapter(
            database,
            'Asset',
            ['indexID'],
            (Asset item) => <String, Object?>{
                  'indexID': item.indexID,
                  'thumbnailID': item.thumbnailID,
                  'lastRefreshedTime':
                      _nullableDateTimeConverter.encode(item.lastRefreshedTime),
                  'artistID': item.artistID,
                  'artistName': item.artistName,
                  'artistURL': item.artistURL,
                  'artists': item.artists,
                  'assetID': item.assetID,
                  'title': item.title,
                  'description': item.description,
                  'mimeType': item.mimeType,
                  'medium': item.medium,
                  'maxEdition': item.maxEdition,
                  'source': item.source,
                  'sourceURL': item.sourceURL,
                  'previewURL': item.previewURL,
                  'thumbnailURL': item.thumbnailURL,
                  'galleryThumbnailURL': item.galleryThumbnailURL,
                  'assetData': item.assetData,
                  'assetURL': item.assetURL,
                  'isFeralfileFrame': item.isFeralfileFrame == null
                      ? null
                      : (item.isFeralfileFrame! ? 1 : 0),
                  'initialSaleModel': item.initialSaleModel,
                  'originalFileURL': item.originalFileURL,
                  'artworkMetadata': item.artworkMetadata
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Asset> _assetInsertionAdapter;

  final UpdateAdapter<Asset> _assetUpdateAdapter;

  @override
  Future<List<Asset>> findAllAssets() async {
    return _queryAdapter.queryList('SELECT * FROM Asset',
        mapper: (Map<String, Object?> row) => Asset(
            indexID: row['indexID'] as String?,
            thumbnailID: row['thumbnailID'] as String?,
            lastRefreshedTime: _nullableDateTimeConverter
                .decode(row['lastRefreshedTime'] as int?),
            artistID: row['artistID'] as String?,
            artistName: row['artistName'] as String?,
            artistURL: row['artistURL'] as String?,
            artists: row['artists'] as String?,
            assetID: row['assetID'] as String?,
            title: row['title'] as String?,
            description: row['description'] as String?,
            mimeType: row['mimeType'] as String?,
            medium: row['medium'] as String?,
            maxEdition: row['maxEdition'] as int?,
            source: row['source'] as String?,
            sourceURL: row['sourceURL'] as String?,
            previewURL: row['previewURL'] as String?,
            thumbnailURL: row['thumbnailURL'] as String?,
            galleryThumbnailURL: row['galleryThumbnailURL'] as String?,
            assetData: row['assetData'] as String?,
            assetURL: row['assetURL'] as String?,
            initialSaleModel: row['initialSaleModel'] as String?,
            originalFileURL: row['originalFileURL'] as String?,
            isFeralfileFrame: row['isFeralfileFrame'] == null
                ? null
                : (row['isFeralfileFrame'] as int) != 0,
            artworkMetadata: row['artworkMetadata'] as String?));
  }

  @override
  Future<List<Asset>> findAllAssetsByIndexIDs(List<String> indexIDs) async {
    const offset = 1;
    final _sqliteVariablesForIndexIDs =
        Iterable<String>.generate(indexIDs.length, (i) => '?${i + offset}')
            .join(',');
    return _queryAdapter.queryList(
        'SELECT * FROM Asset WHERE indexID IN (' +
            _sqliteVariablesForIndexIDs +
            ')',
        mapper: (Map<String, Object?> row) => Asset(
            indexID: row['indexID'] as String?,
            thumbnailID: row['thumbnailID'] as String?,
            lastRefreshedTime: _nullableDateTimeConverter
                .decode(row['lastRefreshedTime'] as int?),
            artistID: row['artistID'] as String?,
            artistName: row['artistName'] as String?,
            artistURL: row['artistURL'] as String?,
            artists: row['artists'] as String?,
            assetID: row['assetID'] as String?,
            title: row['title'] as String?,
            description: row['description'] as String?,
            mimeType: row['mimeType'] as String?,
            medium: row['medium'] as String?,
            maxEdition: row['maxEdition'] as int?,
            source: row['source'] as String?,
            sourceURL: row['sourceURL'] as String?,
            previewURL: row['previewURL'] as String?,
            thumbnailURL: row['thumbnailURL'] as String?,
            galleryThumbnailURL: row['galleryThumbnailURL'] as String?,
            assetData: row['assetData'] as String?,
            assetURL: row['assetURL'] as String?,
            initialSaleModel: row['initialSaleModel'] as String?,
            originalFileURL: row['originalFileURL'] as String?,
            isFeralfileFrame: row['isFeralfileFrame'] == null
                ? null
                : (row['isFeralfileFrame'] as int) != 0,
            artworkMetadata: row['artworkMetadata'] as String?),
        arguments: [...indexIDs]);
  }

  @override
  Future<List<String>> findAllIndexIDs() async {
    return _queryAdapter.queryList('SELECT indexID FROM Asset',
        mapper: (Map<String, Object?> row) => row.values.first as String);
  }

  @override
  Future<void> deleteAssetByIndexID(String indexID) async {
    await _queryAdapter.queryNoReturn('DELETE FROM Asset WHERE indexID = (?1)',
        arguments: [indexID]);
  }

  @override
  Future<void> removeAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM Asset');
  }

  @override
  Future<void> insertAsset(Asset token) async {
    await _assetInsertionAdapter.insert(token, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertAssets(List<Asset> assets) async {
    await _assetInsertionAdapter.insertList(assets, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertAssetsAbort(List<Asset> assets) async {
    await _assetInsertionAdapter.insertList(assets, OnConflictStrategy.ignore);
  }

  @override
  Future<void> updateAsset(Asset asset) async {
    await _assetUpdateAdapter.update(asset, OnConflictStrategy.abort);
  }
}

class _$ProvenanceDao extends ProvenanceDao {
  _$ProvenanceDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _provenanceInsertionAdapter = InsertionAdapter(
            database,
            'Provenance',
            (Provenance item) => <String, Object?>{
                  'id': item.id,
                  'txID': item.txID,
                  'type': item.type,
                  'blockchain': item.blockchain,
                  'owner': item.owner,
                  'timestamp': _dateTimeConverter.encode(item.timestamp),
                  'txURL': item.txURL,
                  'tokenID': item.tokenID,
                  'blockNumber': item.blockNumber
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Provenance> _provenanceInsertionAdapter;

  @override
  Future<List<Provenance>> findProvenanceByTokenID(String tokenID) async {
    return _queryAdapter.queryList(
        'SELECT * FROM Provenance WHERE tokenID = ?1',
        mapper: (Map<String, Object?> row) => Provenance(
            id: row['id'] as String,
            type: row['type'] as String,
            blockchain: row['blockchain'] as String,
            txID: row['txID'] as String,
            owner: row['owner'] as String,
            timestamp: _dateTimeConverter.decode(row['timestamp'] as int),
            txURL: row['txURL'] as String,
            tokenID: row['tokenID'] as String,
            blockNumber: row['blockNumber'] as int?),
        arguments: [tokenID]);
  }

  @override
  Future<void> deleteProvenanceNotBelongs(List<String> tokenIDs) async {
    const offset = 1;
    final _sqliteVariablesForTokenIDs =
        Iterable<String>.generate(tokenIDs.length, (i) => '?${i + offset}')
            .join(',');
    await _queryAdapter.queryNoReturn(
        'DELETE FROM Provenance WHERE tokenID NOT IN (' +
            _sqliteVariablesForTokenIDs +
            ')',
        arguments: [...tokenIDs]);
  }

  @override
  Future<void> removeAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM Provenance');
  }

  @override
  Future<void> insertProvenance(List<Provenance> provenance) async {
    await _provenanceInsertionAdapter.insertList(
        provenance, OnConflictStrategy.replace);
  }
}

class _$AddressCollectionDao extends AddressCollectionDao {
  _$AddressCollectionDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _addressCollectionInsertionAdapter = InsertionAdapter(
            database,
            'AddressCollection',
            (AddressCollection item) => <String, Object?>{
                  'address': item.address,
                  'lastRefreshedTime':
                      _dateTimeConverter.encode(item.lastRefreshedTime),
                  'isHidden': item.isHidden ? 1 : 0
                }),
        _addressCollectionUpdateAdapter = UpdateAdapter(
            database,
            'AddressCollection',
            ['address'],
            (AddressCollection item) => <String, Object?>{
                  'address': item.address,
                  'lastRefreshedTime':
                      _dateTimeConverter.encode(item.lastRefreshedTime),
                  'isHidden': item.isHidden ? 1 : 0
                }),
        _addressCollectionDeletionAdapter = DeletionAdapter(
            database,
            'AddressCollection',
            ['address'],
            (AddressCollection item) => <String, Object?>{
                  'address': item.address,
                  'lastRefreshedTime':
                      _dateTimeConverter.encode(item.lastRefreshedTime),
                  'isHidden': item.isHidden ? 1 : 0
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<AddressCollection> _addressCollectionInsertionAdapter;

  final UpdateAdapter<AddressCollection> _addressCollectionUpdateAdapter;

  final DeletionAdapter<AddressCollection> _addressCollectionDeletionAdapter;

  @override
  Future<List<AddressCollection>> findAllAddresses() async {
    return _queryAdapter.queryList('SELECT * FROM AddressCollection',
        mapper: (Map<String, Object?> row) => AddressCollection(
            address: row['address'] as String,
            lastRefreshedTime:
                _dateTimeConverter.decode(row['lastRefreshedTime'] as int),
            isHidden: (row['isHidden'] as int) != 0));
  }

  @override
  Future<List<AddressCollection>> findAddresses(List<String> addresses) async {
    const offset = 1;
    final _sqliteVariablesForAddresses =
        Iterable<String>.generate(addresses.length, (i) => '?${i + offset}')
            .join(',');
    return _queryAdapter.queryList(
        'SELECT * FROM AddressCollection WHERE address IN (' +
            _sqliteVariablesForAddresses +
            ')',
        mapper: (Map<String, Object?> row) => AddressCollection(
            address: row['address'] as String,
            lastRefreshedTime:
                _dateTimeConverter.decode(row['lastRefreshedTime'] as int),
            isHidden: (row['isHidden'] as int) != 0),
        arguments: [...addresses]);
  }

  @override
  Future<List<String>> findAddressesIsHidden(bool isHidden) async {
    return _queryAdapter.queryList(
        'SELECT address FROM AddressCollection WHERE isHidden = ?1',
        mapper: (Map<String, Object?> row) => row.values.first as String,
        arguments: [isHidden ? 1 : 0]);
  }

  @override
  Future<void> setAddressIsHidden(
    List<String> addresses,
    bool isHidden,
  ) async {
    const offset = 2;
    final _sqliteVariablesForAddresses =
        Iterable<String>.generate(addresses.length, (i) => '?${i + offset}')
            .join(',');
    await _queryAdapter.queryNoReturn(
        'UPDATE AddressCollection SET isHidden = ?1 WHERE address IN (' +
            _sqliteVariablesForAddresses +
            ')',
        arguments: [isHidden ? 1 : 0, ...addresses]);
  }

  @override
  Future<void> updateRefreshTime(
    List<String> addresses,
    int time,
  ) async {
    const offset = 2;
    final _sqliteVariablesForAddresses =
        Iterable<String>.generate(addresses.length, (i) => '?${i + offset}')
            .join(',');
    await _queryAdapter.queryNoReturn(
        'UPDATE AddressCollection SET lastRefreshedTime = ?1 WHERE address IN (' +
            _sqliteVariablesForAddresses +
            ')',
        arguments: [time, ...addresses]);
  }

  @override
  Future<void> deleteAddresses(List<String> addresses) async {
    const offset = 1;
    final _sqliteVariablesForAddresses =
        Iterable<String>.generate(addresses.length, (i) => '?${i + offset}')
            .join(',');
    await _queryAdapter.queryNoReturn(
        'DELETE FROM AddressCollection WHERE address IN (' +
            _sqliteVariablesForAddresses +
            ')',
        arguments: [...addresses]);
  }

  @override
  Future<void> removeAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM AddressCollection');
  }

  @override
  Future<void> insertAddresses(List<AddressCollection> addresses) async {
    await _addressCollectionInsertionAdapter.insertList(
        addresses, OnConflictStrategy.replace);
  }

  @override
  Future<void> insertAddressesAbort(List<AddressCollection> addresses) async {
    await _addressCollectionInsertionAdapter.insertList(
        addresses, OnConflictStrategy.ignore);
  }

  @override
  Future<void> updateAddresses(List<AddressCollection> addresses) async {
    await _addressCollectionUpdateAdapter.updateList(
        addresses, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteAddress(AddressCollection address) async {
    await _addressCollectionDeletionAdapter.delete(address);
  }
}

// ignore_for_file: unused_element
final _dateTimeConverter = DateTimeConverter();
final _nullableDateTimeConverter = NullableDateTimeConverter();
final _tokenOwnersConverter = TokenOwnersConverter();
