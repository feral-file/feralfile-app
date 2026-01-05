part of 'user_all_own_collection_bloc.dart';

/// Base event for UserAllOwnCollectionBloc.
///
/// Each event must provide a [streamKey] that uniquely identifies
/// long-running operations (streams/completers) triggered by that event.
/// This allows the bloc to track multiple concurrent operations of
/// the same event type but different parameters (e.g. different addresses).
abstract class UserAllOwnCollectionEvent {
  /// Unique key used to track stream subscriptions and completers
  /// for long-running operations started by this event.
  String get streamKey;
}

class FetchTokensOfAddresses extends UserAllOwnCollectionEvent {
  FetchTokensOfAddresses({
    required this.addresses,
    this.shouldUpdateLastRefreshedTime = false,
    this.shouldUpdateAddressState = true,
    this.onDone,
    this.onError,
  }) {
    if (addresses.isEmpty) {
      return;
    }
  }
  final List<String> addresses;
  final bool shouldUpdateLastRefreshedTime;
  final bool shouldUpdateAddressState;
  final void Function()? onDone;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  String get streamKey =>
      'FetchTokensOfAddresses:${addresses.join(',')}_${shouldUpdateAddressState}_${shouldUpdateLastRefreshedTime}';
}

class UpdateDynamicQueryEvent extends UserAllOwnCollectionEvent {
  UpdateDynamicQueryEvent({required this.dynamicQuery});

  final DynamicQuery dynamicQuery;

  @override
  String get streamKey => 'UpdateDynamicQueryEvent:${dynamicQuery.toJson()}';
}

class ReloadAssetTokensFromIndexerDatabase extends UserAllOwnCollectionEvent {
  ReloadAssetTokensFromIndexerDatabase(
      {this.sortBy = IndexerDatabaseSortBy.updatedAt});

  final IndexerDatabaseSortBy sortBy;

  @override
  String get streamKey => 'ReloadAssetTokensFromIndexerDatabase';
}

class ClearDataEvent extends UserAllOwnCollectionEvent {
  @override
  String get streamKey => 'ClearDataEvent';
}

class ReindexAddresses extends UserAllOwnCollectionEvent {
  ReindexAddresses({
    required this.addresses,
  });

  final List<String> addresses;

  @override
  String get streamKey => 'ReindexAddresses:${addresses.join(',')}';
}

class WorkflowStatusTick extends UserAllOwnCollectionEvent {
  WorkflowStatusTick({
    required this.operationId,
    required this.addresses,
    required this.workflowId,
    required this.runId,
    required this.status,
  });

  final String operationId;
  final List<String> addresses;
  final String workflowId;
  final String runId;
  final WorkflowExecutionStatus status;

  @override
  String get streamKey => 'WorkflowStatusTick:$operationId';
}

class UpdateTokensOfAddresses extends UserAllOwnCollectionEvent {
  UpdateTokensOfAddresses({
    required this.addresses,
  });

  final List<String> addresses;

  @override
  String get streamKey => 'UpdateTokensOfAddresses:${addresses.join(',')}';
}
