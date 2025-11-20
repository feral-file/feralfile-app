import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/dp1_carousel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_list_item_widget.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';

/// Playlist List Row - Combines list item info with carousel content
class PlaylistListRow extends StatelessWidget {
  const PlaylistListRow({
    required this.playlistReference,
    required this.carouselItems,
    this.playlistCreator,
    this.onItemTap,
    this.scrollController,
    super.key,
  });

  final PlaylistReference playlistReference;
  final List<DP1NowDisplayingItem> carouselItems;
  final String? playlistCreator;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final playlist = playlistReference.playlist;
    final playlistTitle = playlist.title;
    final creator = playlistCreator ?? 'Playlist Creator';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRouter.dp1PlaylistDetailsPage,
          arguments: DP1PlaylistDetailsScreenPayload(
            playlist: playlistReference,
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.black,
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlaylistListItemWidget(
              primaryText: playlistTitle,
              secondaryText: creator,
            ),
            DP1Carousel(
              items: carouselItems,
              onItemTap: onItemTap,
              scrollController: scrollController,
            ),
          ],
        ),
      ),
    );
  }
}
