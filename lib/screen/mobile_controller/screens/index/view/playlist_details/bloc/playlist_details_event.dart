abstract class PlaylistDetailsEvent {}

class GetPlaylistDetailsEvent extends PlaylistDetailsEvent {
  final int size;
  GetPlaylistDetailsEvent({int? size}) : size = size ?? 10;
}

class LoadMorePlaylistDetailsEvent extends PlaylistDetailsEvent {}

class UpdateTotalEvent extends PlaylistDetailsEvent {}
