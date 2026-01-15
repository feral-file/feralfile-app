part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, loading, loaded, error }

enum AddressStateType {
  indexStated,
  indexingDone,
  indexingIncomplete,
  fetchingArtworks,
  fetchingArtworksFailed,
  fetchingArtworksDone;

  String get description {
    switch (this) {
      case AddressStateType.indexStated:
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
  final String address;
  final List<AssetToken> assetTokens;
  final AddressStateType state;
  final AddressIndexingJobResponse? indexingStatus;

  AddressState({
    required this.address,
    required this.assetTokens,
    required this.state,
    this.indexingStatus,
  }) {
    if (indexingStatus == null) {
      log.info('indexingStatus is null for address: $address');
    }
  }

  AddressState copyWith({
    String? address,
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
  AddressState? getAddressState(String address) {
    return firstWhere((state) => state.address == address);
  }

  // Helper method to update status for a single address

  AddressStateType _mapIndexingStatusToStateType(IndexingJobStatus status) {
    switch (status) {
      case IndexingJobStatus.running:
      case IndexingJobStatus.paused:
        return AddressStateType.indexStated;
      case IndexingJobStatus.completed:
        return AddressStateType.indexingDone;
      case IndexingJobStatus.failed:
      case IndexingJobStatus.canceled:
        return AddressStateType.indexingIncomplete;
    }
  }
}
