import 'package:autonomy_flutter/model/token.dart' as v2;
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';

enum IndexerDatabaseSortBy { updatedAt }

abstract class IndexerDatabaseAbstract {
  int insertToken(v2.AssetToken token);

  void insertTokens(List<v2.AssetToken> tokens);

  List<v2.AssetToken> getTokensByOwner({
    required String ownerAddress,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  });

  List<AddressAssetTokens> getGroupAssetTokensByOwnersGroupByAddress(
      {required List<String> owners,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt});

  List<v2.AssetToken> getTokensByOwners({
    required List<String> owners,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  });

  List<v2.AssetToken> getTokensByCIDs({
    required List<String> cids,
    IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.updatedAt,
  });

  void clearAll();

  v2.AssetToken? findTokenByCid(String cid);

  void deleteToken(String cid);

  void deleteTokens(List<String> cids);
}
