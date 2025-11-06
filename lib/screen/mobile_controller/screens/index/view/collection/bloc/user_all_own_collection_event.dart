part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class FetchTokensOfAddresses extends UserAllOwnCollectionEvent {
  FetchTokensOfAddresses({
    required this.addresses,
    this.shouldEmitLoading = true,
  });
  final List<String> addresses;
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
    this.shouldEmitLoading = true,
  });

  final List<String> addresses;
  final bool shouldEmitLoading;
}
