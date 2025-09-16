part of 'user_all_own_collection_bloc.dart';

abstract class UserAllOwnCollectionEvent {}

class LoadDynamicQueryEvent extends UserAllOwnCollectionEvent {
  LoadDynamicQueryEvent(this.dynamicQuery, {this.lazy = true});

  final DynamicQuery dynamicQuery;
  // lazy=true: emit on every batch; lazy=false: emit once when completed
  final bool lazy;
}
