part of 'playlists_bloc.dart';

/// Enum for playlist types
enum PlaylistType {
  curated,
  me,
  global;

  String get name => switch (this) {
        PlaylistType.curated => 'Curated',
        PlaylistType.me => 'Me',
        PlaylistType.global => 'Global',
      };

  String get icon => switch (this) {
        PlaylistType.curated => 'assets/images/D.svg',
        PlaylistType.me => 'assets/images/icon_account.svg',
        PlaylistType.global => 'assets/images/icon_global.svg',
      };

  String get description => switch (this) {
        PlaylistType.curated =>
          'Curated playlists are curated by the team\n to help you discover new music.\nView all curated playlists\nby clicking the button below.',
        PlaylistType.me =>
          'Me playlists are playlists created by the user\n to help you discover new music.\nView all me playlists\nby clicking the button below.',
        PlaylistType.global =>
          'Global playlists are playlists created by the team\n to help you discover new music.\nView all global playlists\nby clicking the button below.',
      };
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
