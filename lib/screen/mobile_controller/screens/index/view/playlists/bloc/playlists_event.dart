part of 'playlists_bloc.dart';

/// Enum for playlist types
enum PlaylistType {
  curated,
  me,
  global,
}

abstract class PlaylistsEvent {
  const PlaylistsEvent();
}

class LoadPlaylistsEvent extends PlaylistsEvent {
  const LoadPlaylistsEvent();
}

class LoadMorePlaylistsEvent extends PlaylistsEvent {
  const LoadMorePlaylistsEvent();
}

class RefreshPlaylistsEvent extends PlaylistsEvent {
  const RefreshPlaylistsEvent();
}
