import 'dart:async';

import 'package:autonomy_flutter/util/log.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum HiveStoreId {
  announcement(10),
  draftCustomerSupport(11),
  indexerIdentity(12);

  final int typeId;

  const HiveStoreId(this.typeId);
}

abstract class HiveObject {
  String get hiveId;
}

abstract class HiveStoreObjectService<T> {
  const HiveStoreObjectService({required this.key});

  final String key;

  Future<void> init();

  Future<void> save(T obj, String objId);

  Future<void> delete(String objId);

  T? get(String objId);

  List<T> getAll();

  Future<void> clear();
}

class HiveStoreObjectServiceImpl<T> implements HiveStoreObjectService<T> {
  HiveStoreObjectServiceImpl({required this.key});

  @override
  final String key;

  late final Box<T> _box;

  @override
  Future<void> init() async {
    _box = await Hive.openBox<T>(key);
  }

  @override
  Future<void> delete(String objId) => _box.delete(objId);

  @override
  T? get(String objId) {
    try {
      return _box.get(objId);
    } catch (e) {
      log.info('Hive error getting object from Hive: $e');
      return null;
    }
  }

  @override
  List<T> getAll() => _box.values.toList();

  @override
  Future<void> save(T obj, String objId) async {
    try {
      await _box.put(objId, obj);
    } catch (e) {
      // log.info('Hive error saving object to Hive: $e');
    }
  }

  @override
  Future<void> clear() async {
    await _box.clear();
    log.info('Hive cleared ${_box.name}');
  }
}
