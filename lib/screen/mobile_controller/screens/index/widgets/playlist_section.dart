import 'package:autonomy_flutter/design/build/components/PlaylistSection.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_section_header.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_list_row.dart';
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
    super.key,
  });

  final String sectionName;
  final List<PlaylistData> playlists;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;
  final void Function(DP1NowDisplayingItem)? onPlaylistItemTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length + 2,
      itemBuilder: (context, index) {
        // Header
        if (index == 0) {
          return PlaylistSectionHeader(
            sectionName: sectionName,
            sectionIcon: sectionIcon,
            onViewAllTap: onViewAllTap,
          );
        }

        // Gap
        if (index == 1) {
          return SizedBox(
            height: PlaylistSectionTokens.gap,
          );
        }

        // List items
        final playlistIndex = index - 2;
        final playlist = playlists[playlistIndex];
        return PlaylistListRow(
          playlistTitle: playlist.title,
          playlistCreator: playlist.creator,
          carouselItems: playlist.items,
          onListItemTap: playlist.onListItemTap,
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
    required this.title,
    required this.creator,
    required this.items,
    this.onListItemTap,
  });

  final String title;
  final String creator;
  final List<DP1NowDisplayingItem> items;
  final VoidCallback? onListItemTap;
}
