part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, loading, loaded, error }

class AddressAssetTokens {
  final WalletAddress address;
  final List<AssetToken> assetTokens;

  AddressAssetTokens({
    required this.address,
    required this.assetTokens,
  });
}

class IndexingOperation {
  const IndexingOperation({
    required this.id,
    required this.addresses,
    this.workflowId,
    this.runId,
  });

  final String id; // key of operation
  final List<String> addresses;
  final String? workflowId;
  final String? runId;

  IndexingOperation copyWith({
    List<String>? addresses,
    String? workflowId,
    String? runId,
    bool clearWorkflowIds = false,
  }) {
    return IndexingOperation(
      id: id,
      addresses: addresses ?? this.addresses,
      workflowId: clearWorkflowIds ? null : (workflowId ?? this.workflowId),
      runId: clearWorkflowIds ? null : (runId ?? this.runId),
    );
  }

  String get key => id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexingOperation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class UserAllOwnCollectionState {
  const UserAllOwnCollectionState({
    this.status = UserAllOwnCollectionStatus.initial,
    this.addressAssetTokens = const <AddressAssetTokens>[],
    this.error = '',
    this.indexingOperations = const <IndexingOperation>[],
  });

  final UserAllOwnCollectionStatus status;
  final List<AddressAssetTokens> addressAssetTokens;
  final String error;
  final List<IndexingOperation> indexingOperations;

  bool get isLazyLoading => status == UserAllOwnCollectionStatus.loading;
  bool get isLoaded => status == UserAllOwnCollectionStatus.loaded;
  bool get isError => status == UserAllOwnCollectionStatus.error;

  UserAllOwnCollectionState copyWith({
    UserAllOwnCollectionStatus? status,
    List<AddressAssetTokens>? addressAssetTokens,
    String? error,
    List<IndexingOperation>? indexingOperations,
  }) {
    return UserAllOwnCollectionState(
      status: status ?? this.status,
      addressAssetTokens: addressAssetTokens ?? this.addressAssetTokens,
      error: error ?? this.error,
      indexingOperations: indexingOperations ?? this.indexingOperations,
    );
  }
}
