import 'dart:convert';

import 'package:autonomy_flutter/database/hive_storage_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';

class DP1FeedStorageService extends HiveStorageService {
  DP1FeedStorageService(super.db, super._prefix);

  static const String _ownedIdsKey = 'owned_ids';

  static const String _playlistKeyPrefix = 'playlist';

  static const String _customFeedServerKeyPrefix = 'custom_feed_server';

  String getPlaylistKey(String id) => '$_playlistKeyPrefix:$id';

  String getCustomFeedServerKey(String url) =>
      '$_customFeedServerKeyPrefix:$url';

/*
=======================================================================

Playlist

=======================================================================
*/

  Future<void> insertPlaylists(List<DP1Call> playlists,
      {OnConflict onConflict = OnConflict.override}) async {
    final data = playlists
        .map((e) => {
              'key': getPlaylistKey(e.id),
              'value': jsonEncode(e.toJson()),
            })
        .toList();
    await write(data, onConflict: onConflict);
  }

  List<DP1Call> getPlaylists() {
    return values
        .map((value) =>
            DP1Call.fromJson(jsonDecode(value) as Map<String, dynamic>))
        .toList();
  }

  DP1Call? getPlaylistById(String id) {
    final raw = query([getPlaylistKey(id)]).firstOrNull?['value'];
    if (raw == null || raw.isEmpty) return null;
    return DP1Call.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<bool> deletePlaylistById(String id) => delete([getPlaylistKey(id)]);

  Future<bool> deletePlaylistsByIds(List<String> ids) => delete(ids);

  // Owned playlist IDs helpers
  // List<String> getOwnedPlaylistIds() {
  //   final raw = query([_ownedIdsKey]).firstOrNull?['value'];
  //   if (raw == null || raw.isEmpty) return <String>[];
  //   final list = (jsonDecode(raw) as List).cast<String>();
  //   return list;
  // }

  // Future<void> setOwnedPlaylistIds(List<String> ids,
  //     {OnConflict onConflict = OnConflict.override}) async {
  //   await write([
  //     {
  //       'key': _ownedIdsKey,
  //       'value': jsonEncode(ids),
  //     }
  //   ], onConflict: onConflict);
  // }

  // Future<void> addOwnedPlaylistId(String id) async {
  //   final ids = getOwnedPlaylistIds();
  //   if (!ids.contains(id)) {
  //     ids.add(id);
  //     await setOwnedPlaylistIds(ids);
  //   }
  // }
  //
  // Future<void> removeOwnedPlaylistId(String id) async {
  //   final ids = getOwnedPlaylistIds();
  //   if (ids.remove(id)) {
  //     await setOwnedPlaylistIds(ids);
  //   }
  // }

/*
=======================================================================

Custom Feed Server

=======================================================================
*/

  Future<void> insertCustomFeedServersByUrls(List<String> urls,
      {OnConflict onConflict = OnConflict.override}) async {
    final data = urls
        .map((e) => {
              'key': getCustomFeedServerKey(e),
              'value': e,
            })
        .toList();
    await write(data, onConflict: onConflict);
  }

  List<String> getCustomFeedServersByUrls() {
    return queryContains(_customFeedServerKeyPrefix)
        .map((e) => e['value'])
        .nonNulls
        .toList();
  }

  Future<bool> deleteCustomFeedServersByUrls(List<String> urls) =>
      delete(urls.map(getCustomFeedServerKey).toList());
}
