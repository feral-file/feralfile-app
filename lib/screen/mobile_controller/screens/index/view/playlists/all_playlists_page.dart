import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_details_header.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_list_row.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

/// All Playlists Page - Displays list of all playlists with curated badges and descriptions
///
/// [playlistType] - The type of playlists to display
///   - [PlaylistType.curated] - Displays all curated playlists
///   - [PlaylistType.me] - Displays all playlists created by the user
///   - [PlaylistType.global] - Displays all global playlists
///

class AllPlaylistsPagePayload {
  const AllPlaylistsPagePayload({required this.playlistType});

  final PlaylistType playlistType;
}

class AllPlaylistsPage extends StatefulWidget {
  const AllPlaylistsPage({super.key, required this.payload});

  final AllPlaylistsPagePayload payload;

  @override
  State<AllPlaylistsPage> createState() => _AllPlaylistsPageState();
}

class _AllPlaylistsPageState extends State<AllPlaylistsPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final ScrollController _scrollController = ScrollController();
  late final PlaylistsBloc _playlistsBloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _playlistsBloc = _getPlaylistsBloc();
    _playlistsBloc.add(const LoadPlaylistsEvent());
  }

  PlaylistsBloc _getPlaylistsBloc() {
    switch (widget.payload.playlistType) {
      case PlaylistType.curated:
        return injector<PlaylistsBloc>(
            instanceName: PlaylistsBlocInstance.curated.instanceName);
      case PlaylistType.me:
        return injector<PlaylistsBloc>(
            instanceName: PlaylistsBlocInstance.my.instanceName);
      case PlaylistType.global:
        return injector<PlaylistsBloc>(
            instanceName: PlaylistsBlocInstance.global.instanceName);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _playlistsBloc.add(const RefreshPlaylistsEvent());
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

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: const CustomAppBar(
        backTitle: 'Index',
      ),
      body: SafeArea(
        child: BlocBuilder<PlaylistsBloc, PlaylistsState>(
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
              child: _buildContent(context, state),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, PlaylistsState state) {
    if (state.isLoading && state.playlistData.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.playlistData.isEmpty) {
      return ErrorView(
        error: 'Error loading playlists: ${state.error}',
        onRetry: () => _playlistsBloc.add(const LoadPlaylistsEvent()),
      );
    }

    return _buildPlaylistsList(context, state);
  }

  Widget _buildPlaylistsList(BuildContext context, PlaylistsState state) {
    final theme = Theme.of(context);
    final playlistDataList = state.playlistData;

    if (playlistDataList.isEmpty) {
      return Center(
        child: Text(
          'No playlists found',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: const SizedBox(height: 21),
        ),
        // PlaylistDetailsHeader
        SliverToBoxAdapter(
          child: PlaylistDetailsHeader(
            icon: SvgPicture.asset(
              widget.payload.playlistType.icon,
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                Color(0xFFFFFFFF),
                BlendMode.srcIn,
              ),
            ),
            title: widget.payload.playlistType.name,
            description: widget.payload.playlistType.description,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),
        // PlaylistList
        SliverList.builder(
          itemBuilder: (context, index) {
            final playlistData = playlistDataList[index];
            return PlaylistListRow(
              playlistReference: playlistData.playlistReference,
              playlistCreator: playlistData.creator,
              carouselItems: playlistData.items,
              onItemTap: (item) {
                final assetToken = item.assetToken;
                if (assetToken != null) {
                  injector<NavigationService>().navigateTo(
                    AppRouter.artworkDetailsPage,
                    arguments:
                        ArtworkDetailPayload(ArtworkIdentity(assetToken.cid)),
                  );
                }
              },
            );
          },
          itemCount: playlistDataList.length,
        ),
        if (state.isLoadingMore)
          SliverToBoxAdapter(
            child: LoadMoreIndicator(
              isLoadingMore: true,
            ),
          ),
        const SliverToBoxAdapter(
          child: BottomSpacing(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
