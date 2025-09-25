part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class RefreshAssetTokens extends UserAllOwnCollectionEvent {
  RefreshAssetTokens({this.shouldEmitLoading = true});
  final bool shouldEmitLoading;
}

class UpdateDynamicQueryEvent extends UserAllOwnCollectionEvent {
  UpdateDynamicQueryEvent({required this.dynamicQuery});

  final DynamicQuery dynamicQuery;
}

class ReloadAssetTokensFromIndexerDatabase extends UserAllOwnCollectionEvent {
  ReloadAssetTokensFromIndexerDatabase(
      {this.sortBy = IndexerDatabaseSortBy.lastActivityTime});

  final IndexerDatabaseSortBy sortBy;
}

class ClearDataEvent extends UserAllOwnCollectionEvent {}
