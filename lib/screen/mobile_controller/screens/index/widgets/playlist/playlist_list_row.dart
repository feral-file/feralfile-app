import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/dp1_carousel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_list_item_widget.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Playlist List Row - Combines list item info with carousel content
class PlaylistListRow extends StatefulWidget {
  const PlaylistListRow({
    required this.playlistReference,
    this.playlistCreator,
    this.onItemTap,
    this.scrollController,
    super.key,
  });

  final PlaylistReference playlistReference;
  final String? playlistCreator;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;

  @override
  State<PlaylistListRow> createState() => _PlaylistListRowState();
}

class _PlaylistListRowState extends State<PlaylistListRow> {
  late PlaylistDetailsBloc _playlistDetailsBloc;
  late ScrollController _carouselScrollController;

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = PlaylistDetailsBloc(
      playlist: widget.playlistReference.playlist,
    );
    _playlistDetailsBloc.add(GetPlaylistDetailsEvent());

    _carouselScrollController = widget.scrollController ?? ScrollController();
    _carouselScrollController.addListener(_onScrollListener);
  }

  @override
  void dispose() {
    _carouselScrollController.removeListener(_onScrollListener);
    if (widget.scrollController == null) {
      _carouselScrollController.dispose();
    }
    _playlistDetailsBloc.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlaylistListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistReference.playlist.id !=
        widget.playlistReference.playlist.id) {
      _playlistDetailsBloc = PlaylistDetailsBloc(
        playlist: widget.playlistReference.playlist,
      );
      _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
    } else {
      final currentItems = oldWidget.playlistReference.playlist.items;
      final newItems = widget.playlistReference.playlist.items;
      if (currentItems.length != newItems.length) {
        _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
      }
    }
  }

  void _onScrollListener() {
    final scrollController = _carouselScrollController;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent * 0.8) {
      _playlistDetailsBloc.add(LoadMorePlaylistDetailsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlistReference.playlist;
    final playlistTitle = playlist.title;
    final creator = widget.playlistCreator ?? 'Playlist Creator';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          AppRouter.dp1PlaylistDetailsPage,
          arguments: DP1PlaylistDetailsScreenPayload(
            playlist: widget.playlistReference,
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
            BlocBuilder<PlaylistDetailsBloc, PlaylistDetailsState>(
              bloc: _playlistDetailsBloc,
              builder: (context, state) {
                return DP1Carousel(
                  items: state.nowDisplayingItems,
                  onItemTap: widget.onItemTap,
                  scrollController: _carouselScrollController,
                  isLoadingMore: state is PlaylistDetailsLoadingMoreState,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
