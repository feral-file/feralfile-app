import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_token_item_view.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistAssetListView extends StatefulWidget {
  PlaylistAssetListView({
    required this.playlist,
    super.key,
    this.backgroundColor = AppColor.auGreyBackground,
    this.padding = EdgeInsets.zero,
    required this.scrollController,
    this.selectedIndex,
  });

  final DP1Call playlist;
  final Color backgroundColor;
  final EdgeInsets padding;
  final ScrollController scrollController;
  final int? selectedIndex;

  @override
  State<PlaylistAssetListView> createState() => _PlaylistAssetListViewState();
}

class _PlaylistAssetListViewState extends State<PlaylistAssetListView> {
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;

  late PlaylistDetailsBloc _playlistDetailsBloc;
  late int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = PlaylistDetailsBloc(widget.playlist);
    _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
    _scrollController = widget.scrollController;
    _scrollController.addListener(_onScroll);
    _selectedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant PlaylistAssetListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist != widget.playlist)
      _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
  }

  @override
  void dispose() {
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      padding: widget.padding.copyWith(top: 0, bottom: 0),
      child: BlocConsumer<PlaylistDetailsBloc, PlaylistDetailsState>(
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: widget.padding.top,
                ),
              ),
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
                      final shouldBlur =
                          _selectedIndex != null && _selectedIndex != index;
                      return Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NowDisplayingTokenItemView(
                                assetToken: assetToken,
                              ),
                              const SizedBox(
                                height: 20,
                              )
                            ],
                          ),
                          if (shouldBlur)
                            Positioned.fill(
                                child: Container(
                              color: AppColor.white.withOpacity(0.5),
                            ))
                        ],
                      );
                    },
                    childCount: state.assetTokens.length,
                  ),
                ),
              if (state is PlaylistDetailsLoadingMoreState)
                const SliverToBoxAdapter(
                    child: LoadMoreIndicator(
                  isLoadingMore: true,
                )),
              SliverToBoxAdapter(
                  child: SizedBox(height: widget.padding.bottom)),
            ],
          );
        },
      ),
    );
  }

  Widget _loadingView(BuildContext context) => LoadingWidget(
        backgroundColor: widget.backgroundColor,
        isInfinitySize: false,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveLayout.paddingHorizontal,
          vertical: 60,
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
