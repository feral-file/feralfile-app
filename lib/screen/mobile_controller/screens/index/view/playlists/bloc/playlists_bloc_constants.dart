/// Enum for PlaylistsBloc instance names in dependency injection
enum PlaylistsBlocInstance {
  /// Curated playlists instance (top 5)
  curated,

  /// User's playlists instance (all)
  my,

  /// Global playlists instance (all)
  global,
}

extension PlaylistsBlocInstanceExt on PlaylistsBlocInstance {
  /// Get the instance name string for dependency injection
  String get instanceName {
    return switch (this) {
      PlaylistsBlocInstance.curated => 'curatedPlaylists',
      PlaylistsBlocInstance.my => 'myPlaylists',
      PlaylistsBlocInstance.global => 'globalPlaylists',
    };
  }
}
