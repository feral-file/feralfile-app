part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, loading, loaded, error }

class AddressAssetTokens {
  final WalletAddress address;
  final List<CompactedAssetToken> compactedAssetTokens;

  AddressAssetTokens({
    required this.address,
    required this.compactedAssetTokens,
  });
}

class UserAllOwnCollectionState {
  const UserAllOwnCollectionState({
    this.status = UserAllOwnCollectionStatus.initial,
    this.addressAssetTokens = const <AddressAssetTokens>[],
    this.error = '',
  });

  final UserAllOwnCollectionStatus status;
  final List<AddressAssetTokens> addressAssetTokens;
  final String error;

  bool get isLazyLoading => status == UserAllOwnCollectionStatus.loading;
  bool get isLoaded => status == UserAllOwnCollectionStatus.loaded;
  bool get isError => status == UserAllOwnCollectionStatus.error;

  UserAllOwnCollectionState copyWith({
    UserAllOwnCollectionStatus? status,
    List<AddressAssetTokens>? addressAssetTokens,
    String? error,
  }) {
    return UserAllOwnCollectionState(
      status: status ?? this.status,
      addressAssetTokens: addressAssetTokens ?? this.addressAssetTokens,
      error: error ?? this.error,
    );
  }
}
