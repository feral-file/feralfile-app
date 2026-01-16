import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'user_all_own_collection_bloc.dart';

/// Internal entry to track bloc and its reference count
class _BlocEntry {
  _BlocEntry({
    required this.bloc,
    this.refCount = 0,
  });

  final UserAllOwnCollectionBloc bloc;
  int refCount;
}

/// Manager for UserAllOwnCollectionBloc instances with reference counting.
///
/// This manager ensures that only one bloc instance exists per address set,
/// and uses reference counting (similar to symlinks) to track how many
/// widgets are using each bloc. The bloc is only closed when the reference
/// count reaches zero.
class UserAllOwnCollectionBlocManager {
  UserAllOwnCollectionBlocManager(this._tokensService);

  final NftTokensService _tokensService;
  final Map<String, _BlocEntry> _blocs = {};

  /// Generate a key from addresses list.
  /// Sorts addresses to ensure same set (different order) gets same key.
  String _generateKey(List<String> addresses) {
    final sorted = List<String>.from(addresses)..sort();
    return sorted.join(',');
  }

  /// Get or create a bloc instance for the given addresses.
  ///
  /// If a bloc for these addresses already exists, increments the reference
  /// count and returns the existing bloc. Otherwise, creates a new bloc,
  /// increments the reference count to 1, and returns it.
  UserAllOwnCollectionBloc getOrCreateBloc(List<String> addresses) {
    if (addresses.isEmpty) {
      log.warning(
        '[UserAllOwnCollectionBlocManager] Cannot create bloc with empty addresses',
      );
      throw ArgumentError('Addresses list cannot be empty');
    }

    final key = _generateKey(addresses);
    final entry = _blocs[key];

    if (entry != null) {
      // Bloc already exists, increment reference count
      entry.refCount++;
      log.info(
        '[UserAllOwnCollectionBlocManager] Incremented refCount for addresses $key to ${entry.refCount}',
      );
      return entry.bloc;
    }

    // Create new bloc
    log.info(
      '[UserAllOwnCollectionBlocManager] Creating new bloc for addresses: $addresses',
    );
    final newBloc = UserAllOwnCollectionBloc(
      _tokensService,
      addresses: addresses,
    );

    // Create entry with refCount = 1
    final newEntry = _BlocEntry(
      bloc: newBloc,
      refCount: 1,
    );
    _blocs[key] = newEntry;

    log.info(
      '[UserAllOwnCollectionBlocManager] Added bloc for addresses $key with refCount = 1',
    );

    return newBloc;
  }

  /// Get an existing bloc instance for the given addresses.
  ///
  /// Returns null if no bloc exists for these addresses.
  /// Note: This does NOT increment the reference count. Use getOrCreateBloc
  /// if you want to track a reference.
  UserAllOwnCollectionBloc? getBlocForAddresses(List<String> addresses) {
    if (addresses.isEmpty) {
      return null;
    }
    final key = _generateKey(addresses);
    return _blocs[key]?.bloc;
  }

  /// Release a reference to a bloc by addresses.
  ///
  /// Decrements the reference count for the bloc. If the reference count
  /// reaches zero, closes the bloc and removes it from the map.
  void releaseBloc(List<String> addresses) {
    if (addresses.isEmpty) {
      return;
    }
    final key = _generateKey(addresses);
    final entry = _blocs[key];

    if (entry == null) {
      log.warning(
        '[UserAllOwnCollectionBlocManager] Attempted to release bloc for addresses $key that does not exist',
      );
      return;
    }

    entry.refCount--;
    log.info(
      '[UserAllOwnCollectionBlocManager] Decremented refCount for addresses $key to ${entry.refCount}',
    );

    if (entry.refCount <= 0) {
      log.info(
        '[UserAllOwnCollectionBlocManager] RefCount reached zero, closing bloc for addresses $key',
      );
      unawaited(entry.bloc.close());
      _blocs.remove(key);
      log.info(
        '[UserAllOwnCollectionBlocManager] Removed bloc for addresses $key from map',
      );
    }
  }

  /// Release a reference to a bloc by bloc instance.
  ///
  /// Finds the bloc in the map and decrements its reference count.
  /// If the reference count reaches zero, closes the bloc and removes it from the map.
  void releaseBlocByInstance(UserAllOwnCollectionBloc bloc) {
    // Find the entry by iterating through the map
    String? foundKey;
    _BlocEntry? foundEntry;

    for (final entry in _blocs.entries) {
      if (entry.value.bloc == bloc) {
        foundKey = entry.key;
        foundEntry = entry.value;
        break;
      }
    }

    if (foundEntry == null || foundKey == null) {
      log.warning(
        '[UserAllOwnCollectionBlocManager] Attempted to release bloc ${bloc.hashCode} that does not exist in manager',
      );
      return;
    }

    foundEntry.refCount--;
    log.info(
      '[UserAllOwnCollectionBlocManager] Decremented refCount for addresses $foundKey to ${foundEntry.refCount}',
    );

    if (foundEntry.refCount <= 0) {
      log.info(
        '[UserAllOwnCollectionBlocManager] RefCount reached zero, closing bloc for addresses $foundKey',
      );
      unawaited(foundEntry.bloc.close());
      _blocs.remove(foundKey);
      log.info(
        '[UserAllOwnCollectionBlocManager] Removed bloc for addresses $foundKey from map',
      );
    }
  }

  /// Dispose a bloc instance for the given addresses immediately.
  ///
  /// This method closes the bloc regardless of its reference count.
  /// Use releaseBloc instead if you want to properly manage reference counting.
  void disposeBloc(List<String> addresses) {
    if (addresses.isEmpty) {
      return;
    }
    final key = _generateKey(addresses);
    final entry = _blocs.remove(key);
    if (entry != null) {
      log.info(
        '[UserAllOwnCollectionBlocManager] Disposing bloc for addresses: $addresses (refCount was ${entry.refCount})',
      );
      unawaited(entry.bloc.close());
    }
  }

  /// Dispose all bloc instances.
  ///
  /// This method disposes all blocs regardless of their reference count.
  /// Use this when the app is shutting down or when you need to clean up
  /// all blocs at once.
  Future<void> disposeAll() async {
    log.info(
      '[UserAllOwnCollectionBlocManager] Disposing all ${_blocs.length} bloc instances',
    );

    final futures = <Future<void>>[];
    for (final entry in _blocs.values) {
      futures.add(entry.bloc.close());
    }

    await Future.wait(futures);
    _blocs.clear();

    log.info(
      '[UserAllOwnCollectionBlocManager] All blocs closed and map cleared',
    );
  }

  /// Get all current bloc instances.
  List<UserAllOwnCollectionBloc> getAllBlocs() {
    return _blocs.values.map((entry) => entry.bloc).toList();
  }
}
