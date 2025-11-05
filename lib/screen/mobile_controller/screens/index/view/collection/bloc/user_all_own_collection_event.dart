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
      {this.sortBy = IndexerDatabaseSortBy.updatedAt});

  final IndexerDatabaseSortBy sortBy;
}

class ClearDataEvent extends UserAllOwnCollectionEvent {}

class PollWorkflowStatus extends UserAllOwnCollectionEvent {
  PollWorkflowStatus({
    required this.addresses,
    this.workflowId,
    this.runId,
  });

  final List<String> addresses;
  final String? workflowId;
  final String? runId;
}
