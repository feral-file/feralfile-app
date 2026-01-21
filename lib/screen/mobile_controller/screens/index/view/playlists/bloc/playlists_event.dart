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
          'Playlists assembled by Feral File and a small group of invited artists and curators. These are early recommendations to help you explore digital art as we build toward deeper, global curation.',
        PlaylistType.me =>
          'Playlists built from the wallet addresses you add. Use it to browse the works you own or to explore any address you’re curious about.',
        PlaylistType.global =>
          'A rotating selection of public playlists and on-chain collections gathered from across the ecosystem. It’s a broad starting point for discovery, not a ranking or popularity list.',
      };
}

abstract class PlaylistsEvent {
  const PlaylistsEvent();
}

class LoadPlaylistsEvent extends PlaylistsEvent {
  LoadPlaylistsEvent() {
    log.info("Create LoadPlaylistsEvent");
  }
}

class LoadMorePlaylistsEvent extends PlaylistsEvent {
  LoadMorePlaylistsEvent() {
    log.info("Create LoadMorePlaylistsEvent");
  }
}

class RefreshPlaylistsEvent extends PlaylistsEvent {
  RefreshPlaylistsEvent({this.size}) {
    log.info("Create RefreshPlaylistsEvent with size: $size");
  }

  /// Optional size to specify how many playlists to load
  /// If null, loads default pageSize
  final int? size;
}
