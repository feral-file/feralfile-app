import 'dart:io';

import 'package:autonomy_flutter/objectbox.g.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';

const objectboxDBFile = 'com.bitmark.feralfile.db';
const objectboxDBFileV2 = 'com.feralfile.v2.db';

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
    final dbPath = p.join(docsDir.path, objectboxDBFileV2);

    // Also check and delete old database if it exists
    try {
      final oldDbPath = p.join(docsDir.path, objectboxDBFile);
      final oldDbDir = Directory(oldDbPath);
      if (await oldDbDir.exists()) {
        await oldDbDir.delete(recursive: true);
        log.info('Deleted old ObjectBox database directory: $oldDbPath');
      }
    } catch (deleteError) {
      log.info('Error deleting old database directory: $deleteError');
    }

    log.info('Opening ObjectBox store at: $dbPath');

    try {
      final store = await openStore(directory: dbPath);
      return ObjectBox._create(store);
    } catch (e) {
      // Handle schema mismatch errors - database has entity IDs that don't match current model
      if (e.toString().contains('last entity ID') &&
          e.toString().contains('is higher than')) {
        log.info(
          'ObjectBox schema mismatch detected. Deleting database and recreating: $e',
        );
        Sentry.captureException(
          'ObjectBox schema mismatch, recreating database: $e',
        );

        // Close store if it was partially opened
        if (_store != null) {
          try {
            await close();
          } catch (_) {
            // Ignore errors when closing
          }
        }

        // Delete the database directory with schema mismatch
        // Wait a bit to ensure store is fully closed
        await Future<void>.delayed(const Duration(milliseconds: 100));

        try {
          final dbDir = Directory(dbPath);
          if (await dbDir.exists()) {
            // Try multiple times to delete, in case file is still locked
            for (int i = 0; i < 3; i++) {
              try {
                await dbDir.delete(recursive: true);
                log.info(
                    'Deleted ObjectBox database directory with schema mismatch: $dbPath');
                break;
              } catch (deleteError) {
                if (i < 2) {
                  log.info(
                      'Retry deleting database directory (attempt ${i + 1}/3): $deleteError');
                  await Future<void>.delayed(const Duration(milliseconds: 200));
                } else {
                  log.info('Error deleting database directory: $deleteError');
                  Sentry.captureException(
                    'Error deleting ObjectBox database: $deleteError',
                  );
                }
              }
            }
          }
        } catch (deleteError) {
          log.info('Error deleting database directory: $deleteError');
          Sentry.captureException(
            'Error deleting ObjectBox database: $deleteError',
          );
        }

        // Try to create store again with fresh database
        final store = await openStore(directory: dbPath);
        return ObjectBox._create(store);
      }
      rethrow;
    }
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

      // Delete lock file for old database
      final oldDbDir = Directory('${dir.path}/$objectboxDBFile');
      final oldLockFile = File('${oldDbDir.path}/objectbox.lock');
      if (await oldLockFile.exists()) {
        await oldLockFile.delete();
        log.info('Deleted stale ObjectBox lock file for old database');
      }

      // Delete lock file for new database
      final newDbDir = Directory('${dir.path}/$objectboxDBFileV2');
      final newLockFile = File('${newDbDir.path}/objectbox.lock');
      if (await newLockFile.exists()) {
        await newLockFile.delete();
        log.info('Deleted stale ObjectBox lock file for new database');
      }
    } catch (e) {
      // Ignore errors when deleting lock file
      Sentry.captureException('Could not delete ObjectBox lock file: $e');
      log.info('Warning: Could not delete ObjectBox lock file: $e');
    }
  }
}
