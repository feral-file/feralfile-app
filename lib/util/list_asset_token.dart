import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

extension CompactedAssetTokenExt on List<CompactedAssetToken> {
  List<PlayListModel> getPlaylistByFilter(
    String Function(CompactedAssetToken) filter,
  ) {
    final groups = groupBy<CompactedAssetToken, String>(
      this,
      filter,
    );
    final playlists = <PlayListModel>[];
    groups.forEach((key, value) {
      final playListModel = PlayListModel(
        name: key,
        tokenIDs: value.map((e) => e.tokenId).whereNotNull().toList(),
        thumbnailURL: value.first.thumbnailURL,
        id: const Uuid().v4(),
      );
      playlists.add(playListModel);
    });
    return playlists;
  }

  List<PlayListModel> getPlaylistByArtists() =>
      getPlaylistByFilter((e) => e.artistID ?? 'Unknown');

  List<PlayListModel> getPlaylistByMedium() =>
      getPlaylistByFilter((e) => e.mimeType ?? 'Unknown');
}
