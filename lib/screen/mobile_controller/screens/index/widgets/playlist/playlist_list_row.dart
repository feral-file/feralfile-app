import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc_manager.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/dp1_carousel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_title.dart';
import 'package:autonomy_flutter/util/debouce_util.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Playlist List Row - Combines list item info with carousel content
class PlaylistRowItem extends StatefulWidget {
  const PlaylistRowItem({
    required this.playlistReference,
    this.playlistCreator,
    this.onItemTap,
    this.scrollController,
    this.headerBuilder,
    super.key,
  });

  final PlaylistReference playlistReference;
  final String? playlistCreator;
  final void Function(DP1NowDisplayingItem)? onItemTap;
  final ScrollController? scrollController;
  final Widget? Function(
          PlaylistReference playlistReference, PlaylistDetailsState state)?
      headerBuilder;

  @override
  State<PlaylistRowItem> createState() => _PlaylistRowItemState();
}

class _PlaylistRowItemState extends State<PlaylistRowItem> {
  late PlaylistDetailsBloc _playlistDetailsBloc;
  late ScrollController _carouselScrollController;

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = injector<PlaylistDetailsBlocManager>().getBloc(
      widget.playlistReference.playlist,
    );

    _carouselScrollController = widget.scrollController ?? ScrollController();
    _carouselScrollController.addListener(_onScrollListener);
  }

  @override
  void dispose() {
    _carouselScrollController.removeListener(_onScrollListener);
    if (widget.scrollController == null) {
      _carouselScrollController.dispose();
    }
    injector<PlaylistDetailsBlocManager>()
        .releaseBlocByInstance(_playlistDetailsBloc);
    super.dispose();
  }

  @override
  void didUpdateWidget(PlaylistRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentItems = oldWidget.playlistReference.playlist.items;
    final newItems = widget.playlistReference.playlist.items;
    if (oldWidget.playlistReference.playlist.id !=
            widget.playlistReference.playlist.id ||
        currentItems.length != newItems.length) {
      injector<PlaylistDetailsBlocManager>()
          .releaseBlocByInstance(_playlistDetailsBloc);
      setState(() {
        _playlistDetailsBloc = injector<PlaylistDetailsBlocManager>().getBloc(
          widget.playlistReference.playlist,
        );
      });
    }
  }

  void _onScrollListener() {
    final scrollController = _carouselScrollController;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent * 0.8) {
      try {
        withDebounce(
          () => _playlistDetailsBloc.add(LoadMorePlaylistDetailsEvent()),
          key: 'playlist_load_more_${_playlistDetailsBloc.hashCode}',
          debounceTime: 500,
        );
      } catch (e) {
        // Debounce blocked - do nothing, already loading
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlistReference.playlist;
    final playlistTitle = playlist.title;
    final creator = widget.playlistCreator ?? '';

    return BlocBuilder<PlaylistDetailsBloc, PlaylistDetailsState>(
      key: ValueKey(_playlistDetailsBloc.hashCode),
      bloc: _playlistDetailsBloc,
      builder: (context, state) {
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
                widget.headerBuilder?.call(widget.playlistReference, state) ??
                    PlaylistTitle(
                      primaryText: playlistTitle,
                      secondaryText: creator,
                    ),
                DP1Carousel(
                  items: state.nowDisplayingItems,
                  onItemTap: widget.onItemTap,
                  scrollController: _carouselScrollController,
                  isLoadingMore: state is PlaylistDetailsLoadingMoreState,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
