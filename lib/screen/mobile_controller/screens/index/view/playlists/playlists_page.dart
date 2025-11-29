import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/all_playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => PlaylistsPageState();
}

class PlaylistsPageState extends State<PlaylistsPage>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final PlaylistsBloc _curatedPlaylistsBloc;
  late final PlaylistsBloc _myPlaylistsBloc;

  @override
  bool get wantKeepAlive => true;

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
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _curatedPlaylistsBloc.add(LoadMorePlaylistsEvent());
      _myPlaylistsBloc.add(LoadMorePlaylistsEvent());
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
        SliverToBoxAdapter(child: _buildMyPlaylists()),
        const SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),
        SliverToBoxAdapter(child: _buildCuratedPlaylists()),
        const SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),
        // _buildGlobalPlaylists(),
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

  Widget _buildContent(PlaylistsState state, PlaylistsBloc playlistsBloc) {
    if (state.isLoading && state.playlists.isEmpty) {
      return const LoadingView();
    }
    if (state.isError && state.playlists.isEmpty) {
      return ErrorView(
        error: 'Error loading playlists: ${state.error}',
        onRetry: () => playlistsBloc.add(LoadPlaylistsEvent()),
      );
    }

    return _buildPlaylists(state, playlistsBloc.playlistType);
  }

  Widget _buildPlaylists(PlaylistsState state, PlaylistType playlistType) {
    // Group playlists by owner for sections
    final playlistDataList = state.playlistData.safeSublist(0, 5);

    final hasMore = state.hasMore;

    return PlaylistSection(
      sectionName: playlistType.name,
      sectionIcon: SvgPicture.asset(
        playlistType.icon,
        width: 12,
        height: 12,
        colorFilter: const ColorFilter.mode(
          PrimitivesTokens.colorsGrey,
          BlendMode.srcIn,
        ),
      ),
      playlists: playlistDataList,
      hasMore: hasMore,
      onViewAllTap: () {
        Navigator.of(context).pushNamed(
          AppRouter.allPlaylistsPage,
          arguments: AllPlaylistsPagePayload(playlistType: playlistType),
        );
      },
      onPlaylistItemTap: (item) {
        final assetToken = item.assetToken;
        if (assetToken != null) {
          injector<NavigationService>().navigateTo(
            AppRouter.artworkDetailsPage,
            arguments: ArtworkDetailPayload(ArtworkIdentity(assetToken.cid),
                useIndexer: true),
          );
        }
      },
    );
  }
}
