import 'dart:convert';

import 'package:autonomy_flutter/database/hive_storage_service.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';

class PlaylistStorageService extends HiveStorageService {
  PlaylistStorageService(super.db, super._prefix);

  Future<bool> deletePlaylists(List<PlayListModel> playlists) =>
      delete(playlists.map((e) => e.key).toList());

  List<PlayListModel> getPlaylists() {
    final playlists = values
        .map((e) =>
            PlayListModel.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
    return playlists;
  }

  PlayListModel? getPlaylistById(String id) {
    final rawString = query([id]).firstOrNull?['value'];
    if (rawString == null || rawString.isEmpty) {
      return null;
    }
    return PlayListModel.fromJson(
        jsonDecode(rawString) as Map<String, dynamic>);
  }

  Future<void> setPlaylists(List<PlayListModel> playlists) async {
    await write(playlists.map((e) => e.toKeyValue).toList());
  }
}
