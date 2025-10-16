import 'package:autonomy_flutter/util/feed_manager.dart';

abstract class FeedRegistryService {
  FeedRegistryService();

  Future<void> starPlaylist(PlaylistReference playlistReference);

  Future<void> unstarPlaylist(PlaylistReference playlistReference);
}

class FeedRegistryServiceImpl extends FeedRegistryService {
  FeedRegistryServiceImpl();

  @override
  Future<void> starPlaylist(PlaylistReference playlistReference) async {
    Future.delayed(const Duration(seconds: 10), () {
      print('starPlaylist: ${playlistReference.playlist.title}');
    });
  }

  @override
  Future<void> unstarPlaylist(PlaylistReference playlistReference) async {
    Future.delayed(const Duration(seconds: 10), () {
      print('unstarPlaylist: ${playlistReference.playlist.title}');
    });
  }
}
