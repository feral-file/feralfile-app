part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, loading, loaded, error }

enum AddressStateType {
  // Initial state
  init, // Initial state when bloc is created

  // Step 1: Index Address states
  indexingIncomplete, // Error ở Step 1: không thể submit indexing job (sau retries)
  indexStated, // Success ở Step 1: đã submit indexing job thành công

  // Step 2: Pull Status states
  getStatusFailed, // Error ở Step 2: không thể pull indexing status (sau retries)
  indexingDone, // Success ở Step 2: indexing job completed

  // Step 3: Fetch Artworks states
  fetchingArtworks, // Đang fetch artworks
  fetchingArtworksFailed, // Error ở Step 3: fetch artworks lỗi
  fetchingArtworksDone; // Success ở Step 3: fetch artworks xong

  String get description {
    switch (this) {
      case AddressStateType.init:
        return 'Syncing...';
      case AddressStateType.indexingIncomplete:
        return 'Sync issue';
      case AddressStateType.indexStated:
        return 'Syncing...';
      case AddressStateType.getStatusFailed:
        return 'Sync issue';
      case AddressStateType.indexingDone:
        return 'Synced';
      case AddressStateType.fetchingArtworks:
        return 'Syncing...';
      case AddressStateType.fetchingArtworksFailed:
        return 'Sync issue';
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
}
