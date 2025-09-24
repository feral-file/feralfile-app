import 'package:autonomy_flutter/nft_collection/models/models.dart';

enum IndexerDatabaseSortBy {
  lastActivityTime,
}

abstract class IndexerDatabaseAbstract {
  void insertAssetToken(AssetToken token);

  void insertAssetTokens(List<AssetToken> tokens);

  List<AssetToken> getAssetTokensByOwner(
      {required String ownerAddress,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime});

  List<AssetToken> getAssetTokensByOwners(
      {required List<String> owners,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime});

  List<AssetToken> getAssetTokensByIndexIds(
      {required List<String> indexIds,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime});

  void clearAll();

  AssetToken? findAssetTokenByIdAndOwner(String id, String owner);
}
