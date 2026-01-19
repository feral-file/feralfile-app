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

class FetchTokens extends UserAllOwnCollectionEvent {
  FetchTokens({
    this.shouldUpdateLastRefreshedTime = false,
    this.shouldUpdateAddressState = false,
    this.onDone,
    this.onError,
  });

  final bool shouldUpdateLastRefreshedTime;
  final bool shouldUpdateAddressState;
  final void Function()? onDone;
  final void Function(Object error, StackTrace stackTrace)? onError;

  @override
  String get streamKey =>
      'FetchTokens:${shouldUpdateAddressState}_${shouldUpdateLastRefreshedTime}';
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

class Reindex extends UserAllOwnCollectionEvent {
  Reindex();

  @override
  String get streamKey => 'Reindex';
}

class AddressIndexingJobStatusTick extends UserAllOwnCollectionEvent {
  AddressIndexingJobStatusTick({
    required this.address,
    required this.workflowId,
    required this.jobStatus,
  });

  final String address;
  final String workflowId;
  final AddressIndexingJobResponse jobStatus;

  @override
  String get streamKey => 'AddressIndexingJobStatusTick:$address';
}

class UpdateTokens extends UserAllOwnCollectionEvent {
  UpdateTokens();

  @override
  String get streamKey => 'UpdateTokens';
}

class PullStatus extends UserAllOwnCollectionEvent {
  @override
  String get streamKey => 'PullStatus';
}
