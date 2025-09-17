part of 'user_all_own_collection_bloc.dart';

enum UserAllOwnCollectionStatus { initial, lazyLoading, loaded, error }

class UserAllOwnCollectionState {
  const UserAllOwnCollectionState({
    this.status = UserAllOwnCollectionStatus.initial,
    this.compactedAssetTokens = const <CompactedAssetToken>[],
    this.error = '',
  });

  final UserAllOwnCollectionStatus status;
  final List<CompactedAssetToken> compactedAssetTokens;
  final String error;

  bool get isLazyLoading => status == UserAllOwnCollectionStatus.lazyLoading;
  bool get isLoaded => status == UserAllOwnCollectionStatus.loaded;
  bool get isError => status == UserAllOwnCollectionStatus.error;

  UserAllOwnCollectionState copyWith({
    UserAllOwnCollectionStatus? status,
    List<CompactedAssetToken>? compactedAssetTokens,
    String? error,
  }) {
    return UserAllOwnCollectionState(
      status: status ?? this.status,
      compactedAssetTokens: compactedAssetTokens ?? this.compactedAssetTokens,
      error: error ?? this.error,
    );
  }
}
