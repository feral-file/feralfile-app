import 'dart:convert';

import 'package:autonomy_flutter/graphql/account_settings/account_settings_db.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_object/base_cloud_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';

class DP1FeedCloudObject extends BaseCloudObject {
  DP1FeedCloudObject(CloudDB db) : super(db);

  static const String _ownedIdsKey = 'owned_ids';

  Future<void> insertPlaylists(List<DP1Call> playlists,
      {OnConflict onConflict = OnConflict.override}) async {
    final data = playlists
        .map((e) => {
              'key': e.id,
              'value': jsonEncode(e.toJson()),
            })
        .toList();
    await db.write(data, onConflict: onConflict);
  }

  List<DP1Call> getPlaylists() {
    return db.values
        .map((value) =>
            DP1Call.fromJson(jsonDecode(value) as Map<String, dynamic>))
        .toList();
  }

  DP1Call? getPlaylistById(String id) {
    final raw = db.query([id]).firstOrNull?['value'];
    if (raw == null || raw.isEmpty) return null;
    return DP1Call.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<bool> deletePlaylistById(String id) => db.delete([id]);

  Future<bool> deletePlaylistsByIds(List<String> ids) => db.delete(ids);

  // Owned playlist IDs helpers
  List<String> getOwnedPlaylistIds() {
    final raw = db.query([_ownedIdsKey]).firstOrNull?['value'];
    if (raw == null || raw.isEmpty) return <String>[];
    final list = (jsonDecode(raw) as List).cast<String>();
    return list;
  }

  Future<void> setOwnedPlaylistIds(List<String> ids,
      {OnConflict onConflict = OnConflict.override}) async {
    await db.write([
      {
        'key': _ownedIdsKey,
        'value': jsonEncode(ids),
      }
    ], onConflict: onConflict);
  }

  Future<void> addOwnedPlaylistId(String id) async {
    final ids = getOwnedPlaylistIds();
    if (!ids.contains(id)) {
      ids.add(id);
      await setOwnedPlaylistIds(ids);
    }
  }

  Future<void> removeOwnedPlaylistId(String id) async {
    final ids = getOwnedPlaylistIds();
    if (ids.remove(id)) {
      await setOwnedPlaylistIds(ids);
    }
  }
}
