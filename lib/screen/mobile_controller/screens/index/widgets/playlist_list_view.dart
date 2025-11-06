import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/material.dart';

class PlaylistListView extends StatelessWidget {
  const PlaylistListView({
    required this.playlists,
    required this.hasMore,
    required this.isLoadingMore,
    required this.scrollController,
    this.channelVisible = true,
    this.isFromPlaylistsPage = false,
    super.key,
  });

  final List<PlaylistReference> playlists;
  final bool hasMore;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final bool channelVisible;
  final bool isFromPlaylistsPage;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: scrollController,
      slivers: [
        UIHelper.playlistSliverListView(
          playlists: playlists,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
          scrollController: scrollController,
          channelVisible: channelVisible,
          isFromPlaylistsPage: isFromPlaylistsPage,
        ),
      ],
    );
  }
}
