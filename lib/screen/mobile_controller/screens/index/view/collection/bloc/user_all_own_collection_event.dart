part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class RefreshAssetTokens extends UserAllOwnCollectionEvent {
  final bool shouldEmitLoading;
  RefreshAssetTokens({this.shouldEmitLoading = false});
}

class UpdateDynamicQueryEvent extends UserAllOwnCollectionEvent {
  UpdateDynamicQueryEvent({required this.dynamicQuery});

  final DynamicQuery dynamicQuery;
}

class ReloadAssetTokensFromIndexerDatabase extends UserAllOwnCollectionEvent {
  final IndexerDatabaseSortBy sortBy;

  ReloadAssetTokensFromIndexerDatabase(
      {this.sortBy = IndexerDatabaseSortBy.lastActivityTime});
}

class ClearDataEvent extends UserAllOwnCollectionEvent {}
