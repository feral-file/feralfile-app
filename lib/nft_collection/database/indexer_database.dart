import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';

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

  List<AddressAssetTokens> getGroupAssetTokensByOwnersGroupByAddress(
      {required List<String> owners,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime});

  List<AssetToken> getAssetTokensByIndexIds(
      {required List<String> indexIds,
      IndexerDatabaseSortBy sortBy = IndexerDatabaseSortBy.lastActivityTime});

  void clearAll();

  AssetToken? findAssetTokenByIdAndOwner(String id, String owner);
}
