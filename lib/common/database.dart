import 'dart:io';
import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';

const objectboxDBFile = 'com.bitmark.feralfile.db';

class ObjectBox {
  /// The Store of this app.
  static Store? _store;
  static bool _isInitialized = false;

  /// Get the current store instance
  static Store get store {
    if (_store == null) {
      throw StateError(
          'ObjectBox store not initialized. Call ObjectBox.create() first.');
    }
    return _store!;
  }

  /// Check if store is already initialized
  static bool get isInitialized => _isInitialized;

  ObjectBox._create(Store storeInstance) {
    _store = storeInstance;
    _isInitialized = true;
  }

  static Future<ObjectBox> create() async {
    // Check if store is already initialized
    if (_isInitialized && _store != null) {
      return ObjectBox._create(_store!);
    }

    // Close existing store if any
    if (_store != null) {
      await close();
    }

    // Delete stale lock file before opening store
    await deleteStaleLock();

    final docsDir = await getApplicationDocumentsDirectory();
    final store =
        await openStore(directory: p.join(docsDir.path, objectboxDBFile));
    return ObjectBox._create(store);
  }

  /// Close the current store
  static Future<void> close() async {
    if (_store != null) {
      _store!.close();
      _store = null;
      _isInitialized = false;
    }
  }

  static Future<void> removeAll() async {}

  /// Delete stale ObjectBox lock file to prevent "another store is still open" error
  static Future<void> deleteStaleLock() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbDir = Directory('${dir.path}/$objectboxDBFile');
      final lockFile = File('${dbDir.path}/objectbox.lock');

      if (await lockFile.exists()) {
        // Double-check no process holds it (safe in most cases)
        await lockFile.delete();
        log.info('Deleted stale ObjectBox lock file');
      }
    } catch (e) {
      // Ignore errors when deleting lock file
      Sentry.captureException('Could not delete ObjectBox lock file: $e');
      log.info('Warning: Could not delete ObjectBox lock file: $e');
    }
  }
}
