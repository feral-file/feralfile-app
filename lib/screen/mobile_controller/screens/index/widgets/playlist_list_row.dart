import 'package:autonomy_flutter/design/build/components/PlaylistListRow.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_list_item_widget.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/dp1_carousel.dart';
import 'package:flutter/material.dart';

/// Playlist List Row - Combines list item info with carousel content
class PlaylistListRow extends StatelessWidget {
  const PlaylistListRow({
    required this.playlistTitle,
    required this.playlistCreator,
    required this.carouselItems,
    this.onItemTap,
    this.onListItemTap,
    this.scrollController,
    super.key,
  });

  final String playlistTitle;
  final String playlistCreator;
  final List<DP1NowDisplayingItem> carouselItems;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final VoidCallback? onListItemTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onListItemTap,
          child: PlaylistListItemWidget(
            primaryText: playlistTitle,
            secondaryText: playlistCreator,
          ),
        ),
        Container(
          height: PlaylistListRowTokens.dividerHeight,
          color: Colors.black,
        ),
        DP1Carousel(
          items: carouselItems,
          onItemTap: onItemTap,
          scrollController: scrollController,
        ),
      ],
    );
  }
}
