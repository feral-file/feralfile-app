import 'package:autonomy_flutter/database/hive_database.dart';
import 'package:autonomy_flutter/util/log.dart';

enum OnConflict { override, skip }

/// Interface for local settings database operations.
/// Implemented by HiveStorageService which uses Hive for local storage.
abstract class StorageService {
  List<Map<String, String>> query(List<String> keys);

  List<Map<String, String>> queryContains(String key);

  Future<void> write(
    List<Map<String, String>> settings, {
    OnConflict onConflict = OnConflict.override,
  });

  Future<bool> delete(List<String> keys);

  String getFullKey(String key);

  Future<void> deleteAll();

  String get prefix;

  List<String> get keys;

  List<String> get values;

  Map<String, String> get allInstance;
}

class HiveStorageService implements StorageService {
  HiveStorageService(this.db, this._prefix);

  final HiveDatabase db;
  final String _prefix;

  @override
  List<Map<String, String>> query(List<String> keys) {
    return keys
        .map((key) {
          final value = db.getString(getFullKey(key)) ?? '';
          return {
            'key': key,
            'value': value,
          };
        })
        .where((element) => element['value']!.isNotEmpty)
        .toList();
  }

  @override
  List<Map<String, String>> queryContains(String key) {
    // Query all keys with prefix, then filter by contains
    final allWithPrefix = db.queryPrefix(_prefix);
    return allWithPrefix
        .where((item) {
          final relativeKey = _removePrefix(item['key']!);
          return relativeKey.contains(key);
        })
        .map((item) => {
              'key': _removePrefix(item['key']!),
              'value': item['value']!,
            })
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
      // Filter out existing keys
      settings.removeWhere((element) {
        final fullKey = getFullKey(element['key']!);
        return db.getString(fullKey) != null;
      });
    }

    if (settings.isEmpty) return;

    for (final setting in settings) {
      final key = getFullKey(setting['key']!);
      final value = setting['value']!;
      await db.setString(key, value);
    }

    log.info(
        '[SettingsDBAdapter] Wrote ${settings.length} settings to $_prefix');
  }

  @override
  Future<bool> delete(List<String> keys) async {
    if (keys.isEmpty) return false;

    for (final key in keys) {
      final fullKey = getFullKey(key);
      await db.delete(fullKey);
    }

    log.info('[SettingsDBAdapter] Deleted ${keys.length} keys from $_prefix');
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
  String get prefix => _prefix;

  @override
  List<String> get keys {
    final allWithPrefix = db.queryPrefix(_prefix);
    return allWithPrefix.map((item) => _removePrefix(item['key']!)).toList();
  }

  @override
  List<String> get values {
    final allWithPrefix = db.queryPrefix(_prefix);
    return allWithPrefix.map((item) => item['value']!).toList();
  }

  @override
  Map<String, String> get allInstance {
    final allWithPrefix = db.queryPrefix(_prefix);
    return {
      for (final item in allWithPrefix)
        _removePrefix(item['key']!): item['value']!
    };
  }

  @override
  Future<void> deleteAll() async {
    await db.deletePrefix(_prefix);
    log.info('[SettingsDBAdapter] Deleted all keys with prefix $_prefix');
  }
}
