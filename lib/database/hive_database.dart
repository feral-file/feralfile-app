import 'package:autonomy_flutter/util/log.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class KeyValueDatabase {
  Future<void> init();
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> delete(String key);
  List<Map<String, String>> queryPrefix(String prefix);
  Future<int> deletePrefix(String prefix);
  Future<void> deleteAll();
  Future<void> close();
}

/// Local key-value database using Hive.
/// Provides simple string storage with prefix-based querying.
class HiveDatabase implements KeyValueDatabase {
  static const _boxName = 'app_storage';
  Box<String>? _box;

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    log.info('[HiveDatabase] Initialized with ${_box!.length} keys');
  }

  /// Get a string value by key
  @override
  String? getString(String key) {
    return _box?.get(key);
  }

  /// Set a string value for a key
  @override
  Future<void> setString(String key, String value) async {
    await _box?.put(key, value);
  }

  /// Delete a key
  @override
  Future<void> delete(String key) async {
    await _box?.delete(key);
  }

  /// Get all keys and values with a given prefix
  @override
  List<Map<String, String>> queryPrefix(String prefix) {
    if (_box == null) return [];

    final results = <Map<String, String>>[];
    for (final key in _box!.keys) {
      if (key.toString().startsWith(prefix)) {
        final value = _box!.get(key);
        if (value != null) {
          results.add({'key': key.toString(), 'value': value});
        }
      }
    }
    return results;
  }

  /// Delete all keys with a given prefix
  @override
  Future<int> deletePrefix(String prefix) async {
    if (_box == null) return 0;

    final keysToDelete =
        _box!.keys.where((key) => key.toString().startsWith(prefix)).toList();

    await _box!.deleteAll(keysToDelete);
    return keysToDelete.length;
  }

  /// Delete all data
  @override
  Future<void> deleteAll() async {
    await _box?.clear();
  }

  /// Close the database
  @override
  Future<void> close() async {
    await _box?.close();
  }
}
