part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, lazyLoading, loaded, error }

class UserAllOwnCollectionState {
  const UserAllOwnCollectionState({
    this.status = UserAllOwnCollectionStatus.initial,
    this.assetTokens = const <CompactedAssetToken>[],
    this.error = '',
    this.isRefreshing = false,
  });

  final UserAllOwnCollectionStatus status;
  final List<CompactedAssetToken> assetTokens;
  final String error;
  final bool isRefreshing;

  bool get isLazyLoading => status == UserAllOwnCollectionStatus.lazyLoading;
  bool get isLoaded => status == UserAllOwnCollectionStatus.loaded;
  bool get isError => status == UserAllOwnCollectionStatus.error;

  UserAllOwnCollectionState copyWith({
    UserAllOwnCollectionStatus? status,
    List<CompactedAssetToken>? assetTokens,
    String? error,
    bool? isRefreshing,
  }) {
    return UserAllOwnCollectionState(
      status: status ?? this.status,
      assetTokens: assetTokens ?? this.assetTokens,
      error: error ?? this.error,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
