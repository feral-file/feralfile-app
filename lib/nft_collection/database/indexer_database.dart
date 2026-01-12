import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';

enum IndexerDatabaseSortBy { updatedAt }

abstract class IndexerDatabaseAbstract {
  // Write operations (async for Drift compatibility)
  Future<void> insertTokens(List<v2.AssetToken> tokens);

  Future<void> clearAll();

  Future<void> deleteToken(String cid);

  Future<void> deleteTokens(List<String> cids);

  // Read operations (async with Future)
  Future<List<AddressAssetTokens>> getGroupAssetTokensByOwnersGroupByAddress({
    required List<String> owners,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  });

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

  // Reactive streams for UI
  Stream<List<v2.AssetToken>> watchTokensByOwners({
    required List<String> owners,
  });

  Stream<List<v2.AssetToken>> watchTokensByCIDs({
    required List<String> cids,
  });
}
