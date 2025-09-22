part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class LazyLoadAssetTokenFromDynamicQuery extends UserAllOwnCollectionEvent {}

class RefreshAssetTokenFromDynamicQuery extends UserAllOwnCollectionEvent {}

class UpdateDynamicQueryEvent extends UserAllOwnCollectionEvent {
  UpdateDynamicQueryEvent({required this.dynamicQuery});

  final DynamicQuery dynamicQuery;
}

class ClearDataEvent extends UserAllOwnCollectionEvent {}
