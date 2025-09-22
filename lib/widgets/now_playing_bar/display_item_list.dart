import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/DisplayItem.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/now_playing_bar/display_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DisplayItemList extends StatefulWidget {
  const DisplayItemList({
    required this.playlist,
    super.key,
    this.selectedIndex,
  });

  final DP1Call playlist;
  final int? selectedIndex;

  @override
  State<DisplayItemList> createState() => _DisplayItemListState();
}

class _DisplayItemListState extends State<DisplayItemList> {
  late PlaylistDetailsBloc _playlistDetailsBloc;
  bool _isLoadingMore = false;
  late final ScrollController _scrollController;

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      final state = _playlistDetailsBloc.state;
      if (state.hasMore && state is! PlaylistDetailsLoadingMoreState) {
        _isLoadingMore = true;
        _playlistDetailsBloc.add(LoadMorePlaylistDetailsEvent());
      }
    }
  }

  void _scrollToSelectedIndex() {
    if (widget.selectedIndex == null) return;

    final scrollPosition = calculateScrollPosition(widget.selectedIndex!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Wait for content to be laid out
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_scrollController.hasClients) {
            final maxExtent = _scrollController.position.maxScrollExtent;
            final target = scrollPosition.clamp(0.0, maxExtent);
            _scrollController.jumpTo(
              target,
            );
          }
        });
      }
    });
  }

  double calculateScrollPosition(int index) {
    const itemHeight = DisplayItemTokens.thumbHeight;
    const gapHeight = NowPlayingBarTokens.bottomDisplayItemListGap;
    const totalItemHeight = itemHeight + gapHeight;
    return index * totalItemHeight.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = PlaylistDetailsBloc(playlist: widget.playlist);
    _playlistDetailsBloc.add(GetPlaylistDetailsEvent());

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _scrollToSelectedIndex();
  }

  @override
  void didUpdateWidget(DisplayItemList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Todo: update function compare playlist
    if (oldWidget.playlist.items.length != widget.playlist.items.length) {
      _playlistDetailsBloc.close();
      _playlistDetailsBloc = PlaylistDetailsBloc(playlist: widget.playlist);
      _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
      _scrollToSelectedIndex();
    }

    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelectedIndex();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _playlistDetailsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlaylistDetailsBloc, PlaylistDetailsState>(
      bloc: _playlistDetailsBloc,
      listener: (context, state) {
        if (state is! PlaylistDetailsLoadingMoreState) {
          _isLoadingMore = false;
        }
      },
      builder: (context, state) {
        return CustomScrollView(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (state is PlaylistDetailsInitialState ||
                state is PlaylistDetailsLoadingState)
              SliverToBoxAdapter(
                child: _loadingView(context),
              )
            else if (state.assetTokens.isEmpty)
              SliverToBoxAdapter(
                child: _emptyView(context),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final assetToken = state.assetTokens[index];
                    return Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DisplayItem(
                              assetToken: assetToken,
                              isPlaying: index == widget.selectedIndex,
                              isInExpandedView: true,
                              onTap: () {
                                final selectedDevice = BluetoothDeviceManager()
                                    .castingBluetoothDevice;
                                if (index != widget.selectedIndex &&
                                    selectedDevice != null) {
                                  injector<CanvasDeviceBloc>().add(
                                    CanvasDeviceMoveToArtworkEvent(
                                      selectedDevice,
                                      index,
                                    ),
                                  );
                                }
                              },
                            ),
                            if (index != state.assetTokens.length - 1)
                              SizedBox(
                                height: NowPlayingBarTokens
                                    .bottomDisplayItemListGap
                                    .toDouble(),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                  childCount: state.assetTokens.length,
                ),
              ),
            if (state is PlaylistDetailsLoadingMoreState)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        NowPlayingBarTokens.bottomDisplayItemListGap.toDouble(),
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _loadingView(BuildContext context) => Container(
        color: NowPlayingBarTokens.bgColor,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.paddingHorizontal,
          vertical: 60,
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.paddingHorizontal,
        vertical: 60,
      ),
      child: Text('Playlist Empty', style: theme.textTheme.ppMori400White14),
    );
  }
}
