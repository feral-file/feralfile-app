part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class LoadDynamicQueryEvent extends UserAllOwnCollectionEvent {
  LoadDynamicQueryEvent(this.dynamicQuery);

  final DynamicQuery dynamicQuery;
}
