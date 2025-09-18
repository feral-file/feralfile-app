import 'package:autonomy_flutter/nft_rendering/nft_loading_widget.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_event.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistAssetGridView extends StatefulWidget {
  const PlaylistAssetGridView({
    required this.playlist,
    super.key,
    this.header,
    this.backgroundColor = AppColor.auGreyBackground,
    this.physics,
  });

  final DP1Call playlist;
  final Widget? header;
  final Color backgroundColor;
  final ScrollPhysics? physics;

  @override
  State<PlaylistAssetGridView> createState() => _PlaylistAssetGridViewState();
}

class _PlaylistAssetGridViewState extends State<PlaylistAssetGridView> {
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;

  late PlaylistDetailsBloc _playlistDetailsBloc;

  @override
  void initState() {
    super.initState();
    _playlistDetailsBloc = PlaylistDetailsBloc(widget.playlist);
    _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PlaylistAssetGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlist != widget.playlist)
      _playlistDetailsBloc.add(GetPlaylistDetailsEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
          physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.header != null) ...[
              SliverToBoxAdapter(
                child: widget.header!,
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: UIConstants.detailPageHeaderPadding,
                ),
              ),
            ],
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
              UIHelper.assetTokenSliverGrid(
                  context, state.assetTokens, widget.playlist.title),
            if (state is PlaylistDetailsLoadingMoreState)
              const SliverToBoxAdapter(
                child: LoadMoreIndicator(
                  isLoadingMore: true,
                ),
              ),
            const SliverToBoxAdapter(
              child: BottomSpacing(),
            ),
          ],
        );
      },
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
