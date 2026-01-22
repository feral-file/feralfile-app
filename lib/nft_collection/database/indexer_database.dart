import 'package:autonomy_flutter/model/token.dart' as v2;

enum IndexerDatabaseSortBy { updatedAt }

abstract class IndexerDatabaseAbstract {
  // Write operations (async for Drift compatibility)
  Future<void> insertTokens(List<v2.AssetToken> tokens);

  Future<void> clearAll();

  Future<void> deleteToken(String cid);

  Future<List<v2.AssetToken>> getTokensByOwners({
    required List<String> owners,
  });

  Future<List<v2.AssetToken>> getTokensByCIDs({
    required List<String> cids,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  });

  Future<v2.AssetToken?> findTokenByCid(String cid);

  Future<List<v2.AssetToken>> getTokensByTokenIds({
    required List<String> tokenIds,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  });
}
