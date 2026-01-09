import 'dart:async';

import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channel_preview_bloc.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/log.dart';

class _ChannelPreviewBlocEntry {
  _ChannelPreviewBlocEntry({
    required this.bloc,
    this.refCount = 0,
  });

  final ChannelPreviewBloc bloc;
  int refCount;
}

/// Manager for ChannelPreviewBloc instances with reference counting.
///
/// This manager ensures that only one bloc instance exists per channel ID,
/// and uses reference counting to track how many widgets are using each bloc.
/// The bloc is only closed when the reference count reaches zero.
class ChannelPreviewBlocManager {
  ChannelPreviewBlocManager._internal();

  static final ChannelPreviewBlocManager _instance =
      ChannelPreviewBlocManager._internal();

  factory ChannelPreviewBlocManager() => _instance;

  /// Map of channel ID to bloc entry
  final Map<String, _ChannelPreviewBlocEntry> _blocs = {};

  /// Get or create a bloc for the given channel reference.
  ///
  /// If a bloc already exists for this channel ID, increments the reference
  /// count and returns the existing bloc. Otherwise, creates a new bloc,
  /// calls [_onBlocCreated], increments the reference count to 1, and returns it.
  ChannelPreviewBloc getBloc({
    required ChannelReference channelReference,
    required int channelItemsPageSize,
  }) {
    final channelId = channelReference.channel.id;
    final entry = _blocs[channelId];

    if (entry != null) {
      entry.refCount++;
      log.info(
        '[ChannelPreviewBlocManager] Incremented refCount for channel $channelId to ${entry.refCount}',
      );
      return entry.bloc;
    }

    final newBloc = ChannelPreviewBloc(
      channelReference: channelReference,
      channelItemsPageSize: channelItemsPageSize,
    );
    log.info(
      '[ChannelPreviewBlocManager] Created new bloc for channel $channelId',
    );

    final newEntry = _ChannelPreviewBlocEntry(
      bloc: newBloc,
      refCount: 0,
    );

    _onBlocCreated(newEntry);

    newEntry.refCount = 1;
    _blocs[channelId] = newEntry;

    log.info(
      '[ChannelPreviewBlocManager] Added bloc for channel $channelId with refCount = 1',
    );

    return newBloc;
  }

  /// Release a reference to a bloc by channel ID.
  ///
  /// Decrements the reference count for the bloc. If the reference count
  /// reaches zero, closes the bloc and removes it from the map.
  void releaseBloc(String channelId) {
    final entry = _blocs[channelId];

    if (entry == null) {
      log.warning(
        '[ChannelPreviewBlocManager] Attempted to release bloc for channel $channelId that does not exist',
      );
      return;
    }

    entry.refCount--;
    log.info(
      '[ChannelPreviewBlocManager] Decremented refCount for channel $channelId to ${entry.refCount}',
    );

    if (entry.refCount <= 0) {
      log.info(
        '[ChannelPreviewBlocManager] RefCount reached zero, closing bloc for channel $channelId',
      );
      unawaited(entry.bloc.close());
      _blocs.remove(channelId);
      log.info(
        '[ChannelPreviewBlocManager] Removed bloc for channel $channelId from map',
      );
    }
  }

  /// Release a reference to a bloc by bloc instance.
  ///
  /// Finds the bloc in the map and decrements its reference count.
  /// If the reference count reaches zero, closes the bloc and removes it from the map.
  void releaseBlocByInstance(ChannelPreviewBloc bloc) {
    String? foundChannelId;
    _ChannelPreviewBlocEntry? foundEntry;

    for (final entry in _blocs.entries) {
      if (entry.value.bloc == bloc) {
        foundChannelId = entry.key;
        foundEntry = entry.value;
        break;
      }
    }

    if (foundEntry == null || foundChannelId == null) {
      log.warning(
        '[ChannelPreviewBlocManager] Attempted to release bloc ${bloc.hashCode} that does not exist in manager',
      );
      return;
    }

    foundEntry.refCount--;
    log.info(
      '[ChannelPreviewBlocManager] Decremented refCount for channel $foundChannelId to ${foundEntry.refCount}',
    );

    if (foundEntry.refCount <= 0) {
      log.info(
        '[ChannelPreviewBlocManager] RefCount reached zero, closing bloc for channel $foundChannelId',
      );
      unawaited(foundEntry.bloc.close());
      _blocs.remove(foundChannelId);
      log.info(
        '[ChannelPreviewBlocManager] Removed bloc for channel $foundChannelId from map',
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
      '[ChannelPreviewBlocManager] Closing all blocs (${_blocs.length} blocs)',
    );

    final futures = <Future<void>>[];
    for (final entry in _blocs.values) {
      futures.add(entry.bloc.close());
    }

    await Future.wait(futures);
    _blocs.clear();

    log.info('[ChannelPreviewBlocManager] All blocs closed and map cleared');
  }

  /// Callback called when a new bloc is created.
  ///
  /// This is called after creating a new bloc entry with refCount = 0,
  /// before incrementing the reference count to 1.
  void _onBlocCreated(_ChannelPreviewBlocEntry entry) {
    log.info(
      '[ChannelPreviewBlocManager] _onBlocCreated called for bloc ${entry.bloc.hashCode} with refCount = ${entry.refCount}',
    );
    entry.bloc.add(const GetChannelPreviewEvent());
  }
}
