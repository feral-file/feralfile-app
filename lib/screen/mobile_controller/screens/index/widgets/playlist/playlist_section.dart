import 'package:autonomy_flutter/design/build/components/PlaylistSection.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_list_row.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section_header.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';

/// Playlist Section - Combines header with list of playlist rows
class PlaylistSection extends StatefulWidget {
  const PlaylistSection({
    required this.sectionName,
    required this.playlists,
    this.sectionIcon,
    this.onViewAllTap,
    this.onPlaylistItemTap,
    this.scrollController,
    this.hasMore = true,
    this.playlistHeaderBuilder,
    super.key,
  });

  final String sectionName;
  final List<PlaylistData> playlists;
  final Widget? sectionIcon;
  final VoidCallback? onViewAllTap;
  final void Function(DP1NowDisplayingItem)? onPlaylistItemTap;
  final ScrollController? scrollController;
  final bool hasMore;
  final Widget? Function(
          PlaylistData playlistData, PlaylistDetailsState playlistDetailsState)?
      playlistHeaderBuilder;

  @override
  State<PlaylistSection> createState() => _PlaylistSectionState();
}

class _PlaylistSectionState extends State<PlaylistSection> {
  @override
  void didUpdateWidget(PlaylistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild if playlists data actually changed
    // This prevents unnecessary rebuilds when only status changes
    if (oldWidget.playlists != widget.playlists ||
        oldWidget.hasMore != widget.hasMore ||
        oldWidget.sectionName != widget.sectionName) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount:
          2 + (widget.playlists.isNotEmpty ? widget.playlists.length : 1),
      itemBuilder: (context, index) {
        // Header
        if (index == 0) {
          return PlaylistSectionHeader(
            sectionName: widget.sectionName,
            sectionIcon: widget.sectionIcon,
            onViewAllTap: widget.hasMore ? widget.onViewAllTap : null,
            hasMore: widget.hasMore,
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
        final playlist = widget.playlists[playlistIndex];
        return PlaylistRowItem(
          playlistReference: playlist.playlistReference,
          playlistCreator: playlist.creator,
          onItemTap: widget.onPlaylistItemTap,
          scrollController: widget.scrollController,
          headerBuilder: widget.playlistHeaderBuilder == null
              ? null
              : (playlistReference, state) =>
                  widget.playlistHeaderBuilder?.call(playlist, state),
        );
      },
    );
  }
}

/// Data model for playlist information
///
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaylistData &&
        playlistReference == other.playlistReference &&
        creator == other.creator;
  }

  @override
  int get hashCode => Object.hash(playlistReference, creator);
}

class AddressPlaylistData extends PlaylistData {
  AddressPlaylistData({
    required super.playlistReference,
    required super.creator,
    required this.address,
  });

  final WalletAddress address;
}
