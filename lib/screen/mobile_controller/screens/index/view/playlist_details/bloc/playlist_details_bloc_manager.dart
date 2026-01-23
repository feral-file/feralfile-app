import 'dart:async';

import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/util/log.dart';

/// Internal entry to track bloc and its reference count
class _BlocEntry {
  _BlocEntry({
    required this.bloc,
    this.refCount = 0,
  });

  final PlaylistDetailsBloc bloc;
  int refCount;
}

/// Manager for PlaylistDetailsBloc instances with reference counting.
///
/// This manager ensures that only one bloc instance exists per playlist ID,
/// and uses reference counting (similar to symlinks) to track how many
/// widgets are using each bloc. The bloc is only closed when the reference
/// count reaches zero.
class PlaylistDetailsBlocManager {
  PlaylistDetailsBlocManager._internal();

  static final PlaylistDetailsBlocManager _instance =
      PlaylistDetailsBlocManager._internal();

  factory PlaylistDetailsBlocManager() => _instance;

  /// Map of playlist ID to bloc entry
  final Map<String, _BlocEntry> _blocs = {};

  /// Get or create a bloc for the given playlist.
  ///
  /// If a bloc already exists for this playlist ID, increments the reference
  /// count and returns the existing bloc. Otherwise, creates a new bloc,
  /// calls [_onBlocCreated], increments the reference count to 1, and returns it.
  PlaylistDetailsBloc getBloc(DP1Call playlist) {
    final playlistId = playlist.id;
    final entry = _blocs[playlistId];

    if (entry != null) {
      // Bloc already exists, increment reference count
      entry.refCount++;
      log.info(
        '[PlaylistDetailsBlocManager] Incremented refCount for playlist $playlistId to ${entry.refCount}',
      );
      return entry.bloc;
    }

    // Create new bloc
    final newBloc = PlaylistDetailsBloc(playlist: playlist);
    log.info(
      '[PlaylistDetailsBlocManager] Created new bloc for playlist $playlistId',
    );

    // Create entry with refCount = 0
    final newEntry = _BlocEntry(
      bloc: newBloc,
      refCount: 0,
    );

    // Call callback with entry (refCount = 0)
    _onBlocCreated(newEntry);

    // Increment refCount to 1
    newEntry.refCount = 1;
    _blocs[playlistId] = newEntry;

    log.info(
      '[PlaylistDetailsBlocManager] Added bloc for playlist $playlistId with refCount = 1',
    );

    return newBloc;
  }

  /// Release a reference to a bloc by playlist ID.
  ///
  /// Decrements the reference count for the bloc. If the reference count
  /// reaches zero, closes the bloc and removes it from the map.
  void releaseBloc(String playlistId, {bool force = false}) {
    final entry = _blocs[playlistId];

    if (entry == null) {
      log.warning(
        '[PlaylistDetailsBlocManager] Attempted to release bloc for playlist $playlistId that does not exist',
      );
      return;
    }

    entry.refCount--;
    log.info(
      '[PlaylistDetailsBlocManager] Decremented refCount for playlist $playlistId to ${entry.refCount}',
    );

    if (entry.refCount <= 0 || force) {
      log.info(
        '[PlaylistDetailsBlocManager] RefCount reached zero, closing bloc for playlist $playlistId',
      );
      unawaited(entry.bloc.close());
      _blocs.remove(playlistId);
      log.info(
        '[PlaylistDetailsBlocManager] Removed bloc for playlist $playlistId from map',
      );
    }
  }

  /// Release a reference to a bloc by bloc instance.
  ///
  /// Finds the bloc in the map and decrements its reference count.
  /// If the reference count reaches zero, closes the bloc and removes it from the map.
  void releaseBlocByInstance(PlaylistDetailsBloc bloc) {
    // Find the entry by iterating through the map
    String? foundPlaylistId;
    _BlocEntry? foundEntry;

    for (final entry in _blocs.entries) {
      if (entry.value.bloc == bloc) {
        foundPlaylistId = entry.key;
        foundEntry = entry.value;
        break;
      }
    }

    if (foundEntry == null || foundPlaylistId == null) {
      log.warning(
        '[PlaylistDetailsBlocManager] Attempted to release bloc ${bloc.hashCode} that does not exist in manager',
      );
      return;
    }

    foundEntry.refCount--;
    log.info(
      '[PlaylistDetailsBlocManager] Decremented refCount for playlist $foundPlaylistId to ${foundEntry.refCount}',
    );

    if (foundEntry.refCount <= 0) {
      log.info(
        '[PlaylistDetailsBlocManager] RefCount reached zero, closing bloc for playlist $foundPlaylistId',
      );
      unawaited(foundEntry.bloc.close());
      _blocs.remove(foundPlaylistId);
      log.info(
        '[PlaylistDetailsBlocManager] Removed bloc for playlist $foundPlaylistId from map',
      );
    }
  }

  /// Close all blocs and clear the map.
  ///
  /// This method disposes all blocs regardless of their reference count.
  /// Use this when the app is shutting down or when you need to clean up
  /// all blocs at once.
  Future<void> close() async {
    log.info(
      '[PlaylistDetailsBlocManager] Closing all blocs (${_blocs.length} blocs)',
    );

    final futures = <Future<void>>[];
    for (final entry in _blocs.values) {
      futures.add(entry.bloc.close());
    }

    await Future.wait(futures);
    _blocs.clear();

    log.info('[PlaylistDetailsBlocManager] All blocs closed and map cleared');
  }

  /// Callback called when a new bloc is created.
  ///
  /// This is called after creating a new bloc entry with refCount = 0,
  /// before incrementing the reference count to 1. Override this method
  /// in subclasses or extend the manager to add custom logic when a bloc is created.
  void _onBlocCreated(_BlocEntry entry) {
    // Default implementation does nothing
    // Can be overridden or extended for custom logic
    log.info(
      '[PlaylistDetailsBlocManager] _onBlocCreated called for bloc ${entry.bloc.hashCode} with refCount = ${entry.refCount}',
    );
    entry.bloc.add(GetPlaylistDetailsEvent());
  }
}
