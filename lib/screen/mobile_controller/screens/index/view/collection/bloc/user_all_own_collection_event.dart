part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class FetchTokensOfAddresses extends UserAllOwnCollectionEvent {
  FetchTokensOfAddresses({
    required this.addresses,
  });
  final List<String> addresses;
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

class ReindexAddresses extends UserAllOwnCollectionEvent {
  ReindexAddresses({
    required this.addresses,
  });

  final List<String> addresses;
}

class WorkflowStatusTick extends UserAllOwnCollectionEvent {
  WorkflowStatusTick({
    required this.operationKey,
    required this.addresses,
    required this.workflowId,
    required this.runId,
    required this.status,
  });

  final String operationKey;
  final List<String> addresses;
  final String workflowId;
  final String runId;
  final WorkflowExecutionStatus status;
}

class UpdateTokensOfAddresses extends UserAllOwnCollectionEvent {
  UpdateTokensOfAddresses({
    required this.addresses,
  });

  final List<String> addresses;
}
