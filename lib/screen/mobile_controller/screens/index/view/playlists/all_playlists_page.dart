import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_details_header.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_list_row.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

/// All Playlists Page - Displays list of all playlists with curated badges and descriptions
class AllPlaylistsPage extends StatefulWidget {
  const AllPlaylistsPage({super.key});

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
    _playlistsBloc = context.read<PlaylistsBloc>();
    _playlistsBloc.add(const LoadPlaylistsEvent());
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
              'assets/images/D.svg',
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                Color(0xFFFFFFFF),
                BlendMode.srcIn,
              ),
            ),
            title: 'Curated',
            description:
                'Curated playlists are curated by the team\n to help you discover new music.\n\nView all curated playlists\nby clicking the button below.',
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
              playlistTitle: playlistData.playlistReference.playlist.title,
              playlistCreator: playlistData.creator,
              carouselItems: playlistData.items,
              onListItemTap: () {
                // Handle playlist tap
              },
            );
          },
          itemCount: playlistDataList.length,
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
