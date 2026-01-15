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
  final AddressIndexingJobResponse? indexingStatus;

  AddressState({
    required this.address,
    required this.assetTokens,
    required this.state,
    this.indexingStatus,
  });

  AddressState copyWith({
    WalletAddress? address,
    List<AssetToken>? assetTokens,
    AddressStateType? state,
    AddressIndexingJobResponse? indexingStatus,
  }) {
    return AddressState(
      address: address ?? this.address,
      assetTokens: assetTokens ?? this.assetTokens,
      state: state ?? this.state,
      indexingStatus: indexingStatus ?? this.indexingStatus,
    );
  }
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
    AddressStateType newState, {
    AddressIndexingJobResponse? indexingStatus,
  }) {
    final updatedStates = map((addressState) {
      if (addresses.contains(addressState.address.address)) {
        return addressState.copyWith(
          state: newState,
          indexingStatus: indexingStatus,
        );
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
              indexingStatus: indexingStatus,
            ),
          );
        }
      }
    }

    return updatedStates;
  }

  // Helper method to update status for a single address
  List<AddressState> updateAddressStatus(
    String address,
    AddressIndexingJobResponse status,
  ) {
    return map((addressState) {
      if (addressState.address.address == address) {
        // Determine AddressStateType from IndexingJobStatus
        final stateType = _mapIndexingStatusToStateType(status.status);
        return addressState.copyWith(
          state: stateType,
          indexingStatus: status,
        );
      }
      return addressState;
    }).toList();
  }

  AddressStateType _mapIndexingStatusToStateType(IndexingJobStatus status) {
    switch (status) {
      case IndexingJobStatus.running:
      case IndexingJobStatus.paused:
        return AddressStateType.indexing;
      case IndexingJobStatus.completed:
        return AddressStateType.indexingDone;
      case IndexingJobStatus.failed:
      case IndexingJobStatus.canceled:
        return AddressStateType.indexingIncomplete;
    }
  }
}
