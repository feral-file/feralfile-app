//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local implementation of CloudDB interface using Hive for key-value storage.
/// This replaces remote account settings with local-only storage.
class LocalAccountSettingsDB implements CloudDB {
  LocalAccountSettingsDB(this._prefix);

  final String _prefix;
  late final Box<String> _box;
  static const String _migrateKey = 'didMigrate';
  static const String _dbName = 'account_settings_db';

  /// Initialize the local database. Must be called before use.
  Future<void> init() async {
    _box = await Hive.openBox<String>('$_dbName.$_prefix');
    log.info('[LocalAccountSettingsDB] Initialized with prefix: $_prefix');
  }

  /// Local DB: no-op (compatibility with CloudDB interface)
  @override
  Future<void> download({List<String>? keys}) async {
    // Local database doesn't need to download from remote
    log.info('[LocalAccountSettingsDB] download called (no-op for local DB)');
  }

  /// Local DB: no-op (compatibility with CloudDB interface)
  @override
  Future<void> uploadCurrentCache() async {
    // Local database doesn't need to upload to remote
    log.info('[LocalAccountSettingsDB] uploadCurrentCache called (no-op for local DB)');
  }

  @override
  List<Map<String, String>> query(List<String> keys) {
    return keys
        .map((key) => {
              'key': key,
              'value': _box.get(key, defaultValue: '') ?? '',
            })
        .where((element) => element['value'] != null && element['value']!.isNotEmpty)
        .map((e) => {'key': e['key']!, 'value': e['value']!})
        .toList();
  }

  @override
  List<Map<String, String>> queryContains(String key) {
    return _box.keys
        .where((k) => k.toString().contains(key))
        .map((k) => {
              'key': k.toString(),
              'value': _box.get(k.toString(), defaultValue: '') ?? '',
            })
        .where((element) => element['value']!.isNotEmpty)
        .toList();
  }

  @override
  Future<void> write(
    List<Map<String, String>> settings, {
    OnConflict onConflict = OnConflict.override,
  }) async {
    settings.removeWhere(
        (element) => element['key'] == null || element['value'] == null);

    if (onConflict == OnConflict.skip) {
      settings.removeWhere((element) => _box.containsKey(element['key']!));
    }

    if (settings.isEmpty) {
      return;
    }

    for (var setting in settings) {
      final key = _removePrefix(setting['key']!);
      final value = setting['value']!;
      await _box.put(key, value);
    }

    log.info('[LocalAccountSettingsDB] Wrote ${settings.length} settings');
  }

  @override
  Future<bool> delete(List<String> keys) async {
    if (keys.isEmpty) {
      return false;
    }

    for (final key in keys) {
      await _box.delete(_removePrefix(key));
    }

    log.info('[LocalAccountSettingsDB] Deleted ${keys.length} keys');
    return true;
  }

  @override
  String getFullKey(String key) {
    if (key.startsWith(_prefix)) {
      return key;
    }
    return '$_prefix.$key';
  }

  String _removePrefix(String key) {
    if (key.startsWith('$_prefix.')) {
      return key.replaceFirst('$_prefix.', '');
    }
    return key;
  }

  @override
  Future<bool> didMigrate() async {
    final value = _box.get(_migrateKey);
    return value == 'true';
  }

  @override
  Future<void> setMigrated() async {
    await _box.put(_migrateKey, 'true');
  }

  @override
  void clearCache() {
    // For local DB, this clears all data
    _box.clear();
    log.info('[LocalAccountSettingsDB] Cache cleared');
  }

  @override
  List<String> get keys =>
      _box.keys
          .where((key) => key.toString() != _migrateKey)
          .map((e) => e.toString())
          .toList();

  @override
  List<String> get values => _box.values.toList();

  @override
  Map<String, String> get allInstance {
    final result = <String, String>{};
    for (final key in _box.keys) {
      final keyStr = key.toString();
      if (keyStr != _migrateKey) {
        final value = _box.get(keyStr);
        if (value != null) {
          result[keyStr] = value;
        }
      }
    }
    return result;
  }

  @override
  String get prefix => _prefix;

  @override
  String get migrateKey => _migrateKey;

  @override
  Future<void> deleteAll() async {
    await _box.clear();
    log.info('[LocalAccountSettingsDB] All data deleted');
  }

  /// Migrate data from remote CloudDB to local storage
  Future<void> migrateFromRemote(CloudDB remoteDB) async {
    log.info('[LocalAccountSettingsDB] Starting migration from remote');
    try {
      // Download all keys from remote
      await remoteDB.download();
      final remoteData = remoteDB.allInstance;

      // Write to local storage
      final settings = remoteData.entries
          .map((e) => {'key': e.key, 'value': e.value})
          .toList();
      if (settings.isNotEmpty) {
        await write(settings);
        log.info('[LocalAccountSettingsDB] Migrated ${settings.length} settings from remote');
      }
    } catch (e, s) {
      log.severe('[LocalAccountSettingsDB] Migration failed: $e', s);
      rethrow;
    }
  }
}

