/*
    "properties": {
      "actor_type": "user",
      "actor_id": "ff1-00023",
      "env_app": "ff-controller",
      "env_app_version": "1.0.0",
      "env_platform": "ios",
      "env_os": "iOS",
      "env_os_version": "26.0.1",
      "env_build_type": "prod",
      "playlist_scope": "feed|generated",
      "playlist_key": "ff-pl-1234",
      "playlist_url": "https://feed.feralfile.com/api/v1/playlists/ff-pl-1234",
      "playlist_feed_host": "feed.feralfile.com"
    }
   */
class ViewPLaylistMetricPayload {
  final String profileId;
  final String envApp;
  final String envAppVersion;
  final String envPlatform;
  final String envOs;
  final String envOsVersion;
  final String envBuildType;
  final PlaylistScope playlistScope;
  final String playlistId;
  final String playlistKey;
  final String? playlistUrl;
  final String playlistDp1Version;
  final String playlistFeedHost;

  ViewPLaylistMetricPayload({
    required this.profileId,
    required this.envApp,
    required this.envAppVersion,
    required this.envPlatform,
    required this.envOs,
    required this.envOsVersion,
    required this.envBuildType,
    required this.playlistScope,
    required this.playlistId,
    required this.playlistKey,
    this.playlistUrl,
    required this.playlistDp1Version,
    required this.playlistFeedHost,
  });

  Map<String, dynamic> toJson() => {
        'profile_id': profileId,
        'env_app': envApp,
        'env_app_version': envAppVersion,
        'env_platform': envPlatform,
        'env_os': envOs,
        'env_os_version': envOsVersion,
        'env_build_type': envBuildType,
        'playlist_scope': playlistScope.value,
        'playlist_id': playlistId,
        'playlist_key': playlistKey,
        if (playlistUrl != null) 'playlist_url': playlistUrl,
        'playlist_dp1_version': playlistDp1Version,
        'playlist_feed_host': playlistFeedHost,
      };
}

enum ActorType {
  ff1,
  ffController;

  String get value {
    switch (this) {
      case ActorType.ff1:
        return 'ff1';
      case ActorType.ffController:
        return 'ff-controller';
    }
  }
}

enum PlaylistScope {
  feed,
  generated;

  String get value {
    switch (this) {
      case PlaylistScope.feed:
        return 'feed';
      case PlaylistScope.generated:
        return 'generated';
    }
  }
}
