import 'dart:async';

import 'package:autonomy_flutter/nft_collection/database/dao/asset_token_dao.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/widgetbook/mock_data/mock_asset_token.dart';

class MockAssetTokenDao implements AssetTokenDao {
  MockAssetTokenDao();

  @override
  Future<List<AssetToken>> findAllAssetTokens() async {
    return MockAssetToken.all;
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensByFilter({
    required String filter,
    bool withHidden = false,
  }) async {
    return MockAssetToken.all.where((token) {
      final title = token.asset?.title?.toLowerCase() ?? '';
      final artistName = token.asset?.artistName?.toLowerCase() ?? '';
      final searchTerm = filter.toLowerCase();
      return title.contains(searchTerm) || artistName.contains(searchTerm);
    }).toList();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensWithoutOffset(
      List<String> owners) async {
    return MockAssetToken.all
        .where((token) => owners.contains(token.owner))
        .toList();
  }

  @override
  Future<DateTime?> getLastRefreshedTime() async {
    return DateTime.now();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensByOwners(
    List<String> owners,
    int limit,
    int lastTime,
    String id,
  ) async {
    return MockAssetToken.all
        .where((token) => owners.contains(token.owner))
        .take(limit)
        .toList();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensBeforeByOwners(
    List<String> owners,
    int lastTime,
    String id,
  ) async {
    return MockAssetToken.all
        .where((token) => owners.contains(token.owner))
        .toList();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensByOwnersAndContractAddress(
    List<String> owners,
    String contractAddress,
    int limit,
    int lastTime,
    String id,
  ) async {
    return MockAssetToken.all
        .where((token) =>
            owners.contains(token.owner) &&
            token.contractAddress == contractAddress)
        .take(limit)
        .toList();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensByArtistID({
    required String artistID,
    bool withHidden = false,
    String filter = "",
  }) async {
    return MockAssetToken.all
        .where((token) => token.asset?.artistID == artistID)
        .toList();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensByMimeTypesOrMediums({
    required List<String> mimeTypes,
    required List<String> mediums,
    bool isInMimeTypes = true,
    bool withHidden = false,
    String filter = "",
  }) async {
    return MockAssetToken.all.where((token) {
      final mimeType = token.asset?.mimeType ?? '';
      final medium = token.asset?.medium ?? '';
      return isInMimeTypes
          ? mimeTypes.contains(mimeType) || mediums.contains(medium)
          : !mimeTypes.contains(mimeType) && !mediums.contains(medium);
    }).toList();
  }

  @override
  Future<List<AssetToken>> findAllAssetTokensByTokenIDs(
      List<String> ids) async {
    return MockAssetToken.all.where((token) => ids.contains(token.id)).toList();
  }

  @override
  Future<AssetToken?> findAssetTokenByIdAndOwner(
      String id, String owner) async {
    return MockAssetToken.all
        .firstWhere((token) => token.id == id && token.owner == owner);
  }

  @override
  Future<List<String>> findAllAssetTokenIDsByOwner(String owner) async {
    return MockAssetToken.all
        .where((token) => token.owner == owner)
        .map((token) => token.id)
        .toList();
  }
}
