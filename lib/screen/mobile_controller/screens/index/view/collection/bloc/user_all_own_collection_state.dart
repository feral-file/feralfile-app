part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, loading, loaded, error }

class UserAllOwnCollectionState {
  const UserAllOwnCollectionState({
    this.status = UserAllOwnCollectionStatus.initial,
    this.assetTokens = const <AssetToken>[],
    this.error = '',
  });

  final UserAllOwnCollectionStatus status;
  final List<AssetToken> assetTokens;
  final String error;

  bool get isLoading => status == UserAllOwnCollectionStatus.loading;
  bool get isLoaded => status == UserAllOwnCollectionStatus.loaded;
  bool get isError => status == UserAllOwnCollectionStatus.error;

  UserAllOwnCollectionState copyWith({
    UserAllOwnCollectionStatus? status,
    List<AssetToken>? assetTokens,
    String? error,
  }) {
    return UserAllOwnCollectionState(
      status: status ?? this.status,
      assetTokens: assetTokens ?? this.assetTokens,
      error: error ?? this.error,
    );
  }
}
