import 'package:equatable/equatable.dart';

abstract class AddLocalFeedServerEvent extends Equatable {
  const AddLocalFeedServerEvent();

  @override
  List<Object?> get props => [];
}

class LoadPlaylistsEvent extends AddLocalFeedServerEvent {
  const LoadPlaylistsEvent(this.url);

  final String url;

  @override
  List<Object?> get props => [url];
}

class AddServerEvent extends AddLocalFeedServerEvent {
  const AddServerEvent();
}

class ClearErrorEvent extends AddLocalFeedServerEvent {
  const ClearErrorEvent();
}

class ResetEvent extends AddLocalFeedServerEvent {
  const ResetEvent();
}
