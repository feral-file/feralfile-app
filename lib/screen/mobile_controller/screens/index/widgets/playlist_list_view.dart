import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_item.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
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
        playlistSliverListView(
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

SliverList playlistSliverListView({
  required List<PlaylistReference> playlists,
  bool hasMore = false,
  bool isLoadingMore = false,
  ScrollController? scrollController,
  bool channelVisible = true,
  bool isFromPlaylistsPage = false,
}) {
  return SliverList.builder(
    itemBuilder: (context, index) {
      if (index == playlists.length) {
        return Column(
          children: [
            LoadMoreIndicator(isLoadingMore: isLoadingMore),
            const BottomSpacing(),
          ],
        );
      }

      final playlist = playlists[index];
      final service =
          injector<FeralFileFeedManager>().getFeedServiceByUrl(playlist.url);
      ChannelReference? channelReference;
      if (service is FeralFileDP1FeedService) {
        final channel = service.getChannelByPlaylistId(playlist.playlist.id);
        if (channel != null) {
          channelReference =
              ChannelReference(channel: channel, url: playlist.url);
        }
      }

      return Column(
        children: [
          PlaylistItem(
            playlistReference: playlist,
            channelReference: channelReference,
            isFromPlaylistsPage: isFromPlaylistsPage,
            channelVisible: channelVisible,
          ),
          if (index == playlists.length - 1 && !hasMore) const BottomSpacing(),
        ],
      );
    },
    itemCount: playlists.length + (hasMore ? 1 : 0),
  );
}
