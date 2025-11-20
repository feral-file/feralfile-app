part of 'channel_detail_bloc.dart';

enum ChannelDetailStateStatus {
  initial,
  loading,
  loadingMore,
  loaded,
  error,
}

@immutable
class ChannelDetailState {
  const ChannelDetailState({
    this.status = ChannelDetailStateStatus.initial,
    this.playlists = const [],
    this.playlistData = const [],
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  final ChannelDetailStateStatus status;
  final List<DP1Call> playlists;
  final List<PlaylistData> playlistData;
  final bool hasMore;
  final String? cursor;
  final String? error;

  ChannelDetailState copyWith({
    ChannelDetailStateStatus? status,
    List<DP1Call>? playlists,
    List<PlaylistData>? playlistData,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return ChannelDetailState(
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
    return other is ChannelDetailState &&
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

  bool get isInitial => status == ChannelDetailStateStatus.initial;
  bool get isLoading => status == ChannelDetailStateStatus.loading;
  bool get isLoadingMore => status == ChannelDetailStateStatus.loadingMore;
  bool get isLoaded => status == ChannelDetailStateStatus.loaded;
  bool get isError => status == ChannelDetailStateStatus.error;
}
