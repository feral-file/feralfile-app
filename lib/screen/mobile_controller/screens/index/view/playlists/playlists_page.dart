import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/dp1_playlist_details.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_section.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final ScrollController _scrollController = ScrollController();
  late final PlaylistsBloc _curatedPlaylistsBloc;
  late final PlaylistsBloc _myPlaylistsBloc;
  late final PlaylistsBloc _globalPlaylistsBloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _curatedPlaylistsBloc = injector<PlaylistsBloc>(
      instanceName: PlaylistsBlocInstance.curated.instanceName,
    );
    _myPlaylistsBloc = injector<PlaylistsBloc>(
      instanceName: PlaylistsBlocInstance.my.instanceName,
    );
    _globalPlaylistsBloc = injector<PlaylistsBloc>(
      instanceName: PlaylistsBlocInstance.global.instanceName,
    );
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
    _curatedPlaylistsBloc.add(const RefreshPlaylistsEvent());
    _myPlaylistsBloc.add(const RefreshPlaylistsEvent());
    _globalPlaylistsBloc.add(const RefreshPlaylistsEvent());
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _curatedPlaylistsBloc.add(const LoadMorePlaylistsEvent());
      _myPlaylistsBloc.add(const LoadMorePlaylistsEvent());
      _globalPlaylistsBloc.add(const LoadMorePlaylistsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        _buildMyPlaylists(),
        SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),
        _buildCuratedPlaylists(),
        SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),
        _buildGlobalPlaylists(),
      ],
    );
  }

  Widget _buildCuratedPlaylists() {
    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      bloc: _curatedPlaylistsBloc,
      builder: (context, state) => _buildContent(state, _curatedPlaylistsBloc),
    );
  }

  Widget _buildMyPlaylists() {
    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      bloc: _myPlaylistsBloc,
      builder: (context, state) => _buildContent(state, _myPlaylistsBloc),
    );
  }

  Widget _buildGlobalPlaylists() {
    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      bloc: _globalPlaylistsBloc,
      builder: (context, state) => _buildContent(state, _globalPlaylistsBloc),
    );
  }

  // return BlocBuilder<PlaylistsBloc, PlaylistsState>(
  //   bloc: _playlistsBloc,
  //   builder: (context, state) {
  //     return RefreshIndicator(
  //       onRefresh: () async {
  //         _playlistsBloc.add(const RefreshPlaylistsEvent());
  //         // Wait for the refresh to complete
  //         await _playlistsBloc.stream.firstWhere(
  //           (state) => state.isLoaded || state.isError,
  //         );
  //       },
  //       backgroundColor: AppColor.primaryBlack,
  //       color: AppColor.white,
  //       child: _buildContent(state),
  //     );
  //   },
  // );

  Widget _buildContent(PlaylistsState state, PlaylistsBloc playlistsBloc) {
    if (state.isLoading && state.playlists.isEmpty) {
      return const SliverToBoxAdapter(
        child: LoadingView(),
      );
    }

    String sectionName = '';
    Widget? sectionIcon;
    switch (playlistsBloc.playlistType) {
      case PlaylistType.curated:
        sectionName = 'Curated';
        sectionIcon = SvgPicture.asset(
          'assets/images/D.svg',
          width: 12,
          height: 12,
          colorFilter: const ColorFilter.mode(
            Color(0xFFFFFFFF),
            BlendMode.srcIn,
          ),
        );
        break;
      case PlaylistType.me:
        sectionName = 'Me';
        sectionIcon = SvgPicture.asset(
          'assets/images/D.svg',
          width: 12,
          height: 12,
          colorFilter: const ColorFilter.mode(
            Color(0xFFFFFFFF),
            BlendMode.srcIn,
          ),
        );
        break;
      case PlaylistType.global:
        sectionName = 'Global';
        sectionIcon = SvgPicture.asset(
          'assets/images/D.svg',
          width: 12,
          height: 12,
          colorFilter: const ColorFilter.mode(
            Color(0xFFFFFFFF),
            BlendMode.srcIn,
          ),
        );
        break;
      default:
        sectionName = 'Unknown';
        sectionIcon = null;
        break;
    }
    if (state.isError && state.playlists.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorView(
          error: 'Error loading playlists: ${state.error}',
          onRetry: () => playlistsBloc.add(const LoadPlaylistsEvent()),
        ),
      );
    }

    return _buildPlaylists(state, sectionName, sectionIcon);
  }

  Widget _buildPlaylists(
      PlaylistsState state, String sectionName, Widget? sectionIcon) {
    // Group playlists by owner for sections
    final onListItemTap = (PlaylistReference playlist) {
      Navigator.of(context).pushNamed(AppRouter.dp1PlaylistDetailsPage,
          arguments: DP1PlaylistDetailsScreenPayload(playlist: playlist));
    };
    final playlistDataList = state.playlistData
        .map((playlist) => playlist.copyWith(
            onListItemTap: () => onListItemTap(playlist.playlistReference)))
        .toList();

    return SliverList.builder(
      itemCount: 1,
      itemBuilder: (context, index) => Column(
        children: [
          PlaylistSection(
            sectionName: sectionName,
            sectionIcon: sectionIcon,
            playlists: playlistDataList,
            onViewAllTap: () {
              Navigator.of(context).pushNamed(AppRouter.allPlaylistsPage);
            },
            onPlaylistItemTap: (item) {
              final assetToken = item.assetToken;
              if (assetToken != null) {
                injector<NavigationService>().navigateTo(
                  AppRouter.artworkDetailsPage,
                  arguments:
                      ArtworkDetailPayload(ArtworkIdentity(assetToken.cid)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
