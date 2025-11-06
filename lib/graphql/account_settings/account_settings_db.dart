import 'package:autonomy_flutter/graphql/account_settings/account_settings_client.dart';
import 'package:autonomy_flutter/util/log.dart';

enum OnConflict { override, skip }

abstract class CloudDB {
  Future<void> download({List<String>? keys});

  Future<void> uploadCurrentCache();

  List<Map<String, String>> query(List<String> keys);

  List<Map<String, String>> queryContains(String key);

  Future<void> write(List<Map<String, String>> settings,
      {OnConflict onConflict = OnConflict.override});

  Future<bool> delete(List<String> keys);

  //Map<String, dynamic> get caches;

  Future<bool> didMigrate();

  Future<void> setMigrated();

  String getFullKey(String key);

  String get migrateKey;

  String get prefix;

  List<String> get keys;

  List<String> get values;

  Map<String, String> get allInstance;

  Future<void> deleteAll();

  void clearCache();
}

class CloudDBImpl implements CloudDB {
  final AccountSettingsClient _client;
  final String _prefix;

  CloudDBImpl(this._client, this._prefix);

  final Map<String, String> _caches = {};

  static const String _migrateKey = 'didMigrate';

  @override
  Future<void> download({List<String>? keys}) async {
    log.info('AccountSettingsDBImpl download');
    late List<Map<String, String>> values;
    if (keys != null) {
      final fullKeys = keys.map(getFullKey).toList();
      log.info('AccountSettingsDBImpl download keys: ${fullKeys.toString()}');
      values = await _client.query(vars: {'keys': fullKeys});
    } else {
      log.info('AccountSettingsDBImpl download search: $_prefix.');
      values = await _client.query(vars: {'search': '$_prefix.'});
    }
    log.info('AccountSettingsDBImpl download values: $values');

    for (var value in values) {
      if (value['key'] == null || value['value'] == null) {
        continue;
      }
      _caches[_removePrefix(value['key']!)] = value['value']!;
    }
    log.info('AccountSettingsDBImpl download done');
  }

  @override
  Future<void> uploadCurrentCache() async {
    final List<Map<String, String>> data = [];
    _caches.forEach((key, value) {
      data.add({'key': getFullKey(key), 'value': value});
    });
    await write(data);
  }

  @override
  List<Map<String, String>> query(List<String> keys) => keys
      .map((key) => {'key': key, 'value': _caches[key]})
      .where((element) => element['value'] != null)
      .map((e) => {'key': e['key']!, 'value': e['value']!})
      .toList();

  @override
  List<Map<String, String>> queryContains(String key) => _caches.entries
      .where((element) => element.key.contains(key))
      .map((e) => {'key': e.key, 'value': e.value})
      .toList();

  @override
  Future<void> write(List<Map<String, String>> settings,
      {OnConflict onConflict = OnConflict.override}) async {
    settings.removeWhere(
        (element) => element['key'] == null || element['value'] == null);
    if (onConflict == OnConflict.skip) {
      settings.removeWhere(
          (element) => _caches.containsKey(_removePrefix(element['key']!)));
    }

    if (settings.isEmpty) {
      return;
    }

    final settingsFullKeys = settings
        .map((e) => {'key': getFullKey(e['key']!), 'value': e['value']!})
        .toList();
    final isSuccess = await _client.write(data: settingsFullKeys);
    if (isSuccess) {
      for (var element in settingsFullKeys) {
        _caches[_removePrefix(element['key']!)] = element['value']!;
      }
    }
  }

  @override
  Future<bool> delete(List<String> keys) async {
    if (keys.isEmpty) {
      return false;
    }
    final fullKeys = keys.map(getFullKey).toList();
    final isSuccess = await _client.delete(vars: {'keys': fullKeys});
    if (isSuccess) {
      _caches.removeWhere((key, value) => keys.contains(key));
    }
    return isSuccess;
  }

  @override
  String getFullKey(String key) {
    if (key.startsWith(_prefix)) {
      return key;
    }
    return '$_prefix.$key';
  }

  String _removePrefix(String key) => key.replaceFirst('$_prefix.', '');

  @override
  Future<bool> didMigrate() async {
    if (_caches[migrateKey] == 'true') {
      return true;
    }
    await download(keys: [migrateKey]);

    return _caches[migrateKey] == 'true';
  }

  @override
  Future<void> setMigrated() async {
    await write([
      {'key': migrateKey, 'value': 'true'}
    ]);
  }

  @override
  void clearCache() {
    _caches.clear();
  }

  @override
  List<String> get keys =>
      _caches.keys.where((element) => element != _migrateKey).toList();

  @override
  List<String> get values => _caches.entries
      .where((element) => element.key != _migrateKey)
      .map((e) => e.value)
      .toList();

  @override
  Map<String, String> get allInstance => {
        for (var entry in _caches.entries)
          if (entry.key != _migrateKey) entry.key: entry.value
      };

  @override
  String get prefix => _prefix;

  @override
  String get migrateKey => _migrateKey;

  @override
  Future<void> deleteAll() async {
    _caches.clear();
    await _client.delete(vars: {'search': '$_prefix.'});
  }
}
