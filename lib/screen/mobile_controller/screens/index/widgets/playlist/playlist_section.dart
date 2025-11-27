import 'package:autonomy_flutter/design/build/components/PlaylistSection.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_list_row.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section_header.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';

/// Playlist Section - Combines header with list of playlist rows
class PlaylistSection extends StatelessWidget {
  const PlaylistSection({
    required this.sectionName,
    required this.playlists,
    this.sectionIcon,
    this.onViewAllTap,
    this.onPlaylistItemTap,
    this.scrollController,
    this.hasMore = true,
    super.key,
  });

  final String sectionName;
  final List<PlaylistData> playlists;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;
  final void Function(DP1NowDisplayingItem)? onPlaylistItemTap;
  final ScrollController? scrollController;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length + 2,
      itemBuilder: (context, index) {
        // Header
        if (index == 0) {
          return PlaylistSectionHeader(
            sectionName: sectionName,
            sectionIcon: sectionIcon,
            onViewAllTap: hasMore ? onViewAllTap : null,
            hasMore: hasMore,
          );
        }

        // Gap
        if (index == 1) {
          return const SizedBox(
            height: PlaylistSectionTokens.gap,
          );
        }

        // List items
        final playlistIndex = index - 2;
        final playlist = playlists[playlistIndex];
        return PlaylistRowItem(
          playlistReference: playlist.playlistReference,
          playlistCreator: playlist.creator,
          onItemTap: onPlaylistItemTap,
          scrollController: scrollController,
        );
      },
    );
  }
}

/// Data model for playlist information
class PlaylistData {
  PlaylistData({
    required this.playlistReference,
    required this.creator,
  });

  final PlaylistReference playlistReference;
  final String creator;

  PlaylistData copyWith({
    PlaylistReference? playlistReference,
    String? creator,
  }) {
    return PlaylistData(
      playlistReference: playlistReference ?? this.playlistReference,
      creator: creator ?? this.creator,
    );
  }
}
