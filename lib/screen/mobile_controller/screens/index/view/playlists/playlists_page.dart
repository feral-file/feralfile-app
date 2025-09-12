import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_list_view.dart';
import 'package:autonomy_flutter/service/dp1_playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final PlaylistsBloc _playlistsBloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _playlistsBloc = context.read<PlaylistsBloc>();
    _playlistsBloc.add(const LoadPlaylistsEvent());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _playlistsBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _playlistsBloc.add(const LoadMorePlaylistsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      bloc: _playlistsBloc,
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            _playlistsBloc.add(const RefreshPlaylistsEvent());
            // Wait for the refresh to complete
            await _playlistsBloc.stream.firstWhere(
              (state) => state.isLoaded || state.isError,
            );
          },
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: _buildContent(state),
        );
      },
    );
  }

  Widget _buildContent(PlaylistsState state) {
    if (state.isLoading && state.playlists.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.playlists.isEmpty) {
      return ErrorView(
        error: 'Error loading playlists: ${state.error}',
        onRetry: () => _playlistsBloc.add(const LoadPlaylistsEvent()),
      );
    }

    return _buildPlaylists(state);
  }

  Widget _buildPlaylists(PlaylistsState state) {
    final playlists = state.playlists;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;

    return PlaylistListView(
      playlists: playlists,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      scrollController: _scrollController,
      isFromPlaylistsPage: true,
      channel: playlists.isNotEmpty
          ? injector<DP1FeedService>()
              .getChannelByPlaylistId(playlists.first.id)
          : null,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
