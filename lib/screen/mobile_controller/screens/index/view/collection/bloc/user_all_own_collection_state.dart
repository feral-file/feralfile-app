part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, loading, loaded, error }

enum AddressStateType {
  indexing,
  indexingDone,
  indexingIncomplete,
  fetchingArtworks,
  fetchingArtworksFailed,
  fetchingArtworksDone;

  String get description {
    switch (this) {
      case AddressStateType.indexing:
        return 'Syncing...';
      case AddressStateType.indexingDone:
        return 'Synced';
      case AddressStateType.indexingIncomplete:
        return 'Some missing';
      case AddressStateType.fetchingArtworks:
        return 'Syncing...';
      case AddressStateType.fetchingArtworksFailed:
        return 'Some missing';
      case AddressStateType.fetchingArtworksDone:
        return 'Synced';
    }
  }
}

class AddressAssetTokens {
  final WalletAddress address;
  final List<AssetToken> assetTokens;

  AddressAssetTokens({
    required this.address,
    required this.assetTokens,
  });
}

class AddressState {
  final WalletAddress address;
  final List<AssetToken> assetTokens;
  final AddressStateType state;

  AddressState({
    required this.address,
    required this.assetTokens,
    required this.state,
  });

  AddressState copyWith({
    WalletAddress? address,
    List<AssetToken>? assetTokens,
    AddressStateType? state,
  }) {
    return AddressState(
      address: address ?? this.address,
      assetTokens: assetTokens ?? this.assetTokens,
      state: state ?? this.state,
    );
  }
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
    this.addressStates = const <AddressState>[],
    this.error = '',
  });

  final UserAllOwnCollectionStatus status;
  final List<AddressState> addressStates;
  final String error;

  bool get isLazyLoading => status == UserAllOwnCollectionStatus.loading;
  bool get isLoaded => status == UserAllOwnCollectionStatus.loaded;
  bool get isError => status == UserAllOwnCollectionStatus.error;

  UserAllOwnCollectionState copyWith({
    UserAllOwnCollectionStatus? status,
    List<AddressState>? addressStates,
    String? error,
  }) {
    return UserAllOwnCollectionState(
      status: status ?? this.status,
      addressStates: addressStates ?? this.addressStates,
      error: error ?? this.error,
    );
  }
}

extension AddressStateListExtension on List<AddressState> {
  List<AddressState> updateStates(
    List<String> addresses,
    AddressStateType newState,
  ) {
    final updatedStates = map((addressState) {
      if (addresses.contains(addressState.address.address)) {
        return addressState.copyWith(state: newState);
      }
      return addressState;
    }).toList();

    // Add new addresses that don't exist in current states
    final existingAddresses = map((state) => state.address.address).toSet();
    for (final addressStr in addresses) {
      if (!existingAddresses.contains(addressStr)) {
        final walletAddress =
            injector<AddressService>().getWalletAddress(addressStr);
        if (walletAddress != null) {
          updatedStates.add(
            AddressState(
              address: walletAddress,
              assetTokens: [],
              state: newState,
            ),
          );
        }
      }
    }

    return updatedStates;
  }
}
