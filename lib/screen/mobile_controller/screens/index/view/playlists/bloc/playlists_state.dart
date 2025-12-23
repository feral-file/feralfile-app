part of 'playlists_bloc.dart';

enum PlaylistsStateStatus {
  initial,
  loading,
  loadingMore,
  loaded,
  error,
}

@immutable
class PlaylistsState {
  const PlaylistsState({
    this.status = PlaylistsStateStatus.initial,
    this.playlists = const [],
    this.playlistData = const [],
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final PlaylistsStateStatus status;
  final List<PlaylistReference> playlists;
  final List<PlaylistData> playlistData;
  final bool hasMore;
  final String? cursor;
  final String? error;

  PlaylistsState copyWith({
    PlaylistsStateStatus? status,
    List<PlaylistReference>? playlists,
    List<PlaylistData>? playlistData,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return PlaylistsState(
      status: status ?? this.status,
      playlists: playlists ?? this.playlists,
      playlistData: playlistData ?? this.playlistData,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaylistsState &&
        other.status == status &&
        other.playlists == playlists &&
        other.playlistData == playlistData &&
        other.hasMore == hasMore &&
        other.cursor == cursor &&
        other.error == error;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        playlists.hashCode ^
        playlistData.hashCode ^
        hasMore.hashCode ^
        cursor.hashCode ^
        error.hashCode;
  }

  bool get isInitial => status == PlaylistsStateStatus.initial;
  bool get isLoading => status == PlaylistsStateStatus.loading;
  bool get isLoadingMore => status == PlaylistsStateStatus.loadingMore;
  bool get isLoaded => status == PlaylistsStateStatus.loaded;
  bool get isError => status == PlaylistsStateStatus.error;

  List<PlaylistData> get top5PlaylistData => playlistData.safeSublist(0, 5);
}
