import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlist_details/bloc/playlist_details_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/all_playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_header_with_collection_state.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_title.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/util/playlist_data_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
        SliverToBoxAdapter(child: _buildCuratedPlaylists()),
        // _buildGlobalPlaylists(),
      ],
    );
  }

  Widget _buildCuratedPlaylists() {
    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      bloc: _curatedPlaylistsBloc,
      buildWhen: (previous, current) {
        final previousTop5PlaylistData = previous.top5PlaylistData;
        final currentTop5PlaylistData = current.top5PlaylistData;
        final isEqualTo =
            previousTop5PlaylistData.isEqualTo(currentTop5PlaylistData);
        return !isEqualTo;
      },
      builder: (context, state) => _buildContent(state, _curatedPlaylistsBloc),
    );
  }

  Widget _buildMyPlaylists() {
    return BlocBuilder<PlaylistsBloc, PlaylistsState>(
      bloc: _myPlaylistsBloc,
      buildWhen: (previous, current) {
        final previousTop5PlaylistData = previous.top5PlaylistData;
        final currentTop5PlaylistData = current.top5PlaylistData;
        final isEqualTo =
            previousTop5PlaylistData.isEqualTo(currentTop5PlaylistData);
        return !isEqualTo;
      },
      builder: (context, state) => _buildContent(state, _myPlaylistsBloc),
    );
  }

  Widget _buildContent(PlaylistsState state, PlaylistsBloc playlistsBloc) {
    if (state.playlistData.isEmpty && !state.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Builder(
          builder: (context) {
            if (state.isLoading && state.playlistData.isEmpty) {
              return const LoadingView();
            }

            if (state.isError && state.playlistData.isEmpty) {
              return ErrorView(
                error: 'Error loading playlists: ${state.error}',
                onRetry: () => playlistsBloc.add(LoadPlaylistsEvent()),
              );
            }

            return _buildPlaylists(state, playlistsBloc.playlistType);
          },
        ),
        SizedBox(height: LayoutConstants.space12),
      ],
    );
  }

  Widget _buildPlaylists(PlaylistsState state, PlaylistType playlistType) {
    // Group playlists by owner for sections
    final playlistDataList = state.top5PlaylistData;

    final hasMore = state.top5PlaylistData.length < state.playlistData.length ||
        state.hasMore;

    Widget? Function(PlaylistData playlistData,
        PlaylistDetailsState playlistDetailsState)? playlistHeaderBuilder;
    if (playlistType == PlaylistType.me) {
      playlistHeaderBuilder = (playlistData, playlistDetailsState) =>
          _mePlaylistHeaderBuilder(playlistData, playlistDetailsState);
    }

    return PlaylistSection(
      sectionName: playlistType.name,
      sectionIcon: SvgPicture.asset(
        playlistType.icon,
        width: LayoutConstants.iconSizeDefault,
        height: LayoutConstants.iconSizeDefault,
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
      playlistHeaderBuilder: playlistHeaderBuilder,
    );
  }

  Widget _mePlaylistHeaderBuilder(
      PlaylistData playlistData, PlaylistDetailsState playlistDetailsState) {
    final playlistReference = playlistData.playlistReference;
    final playlist = playlistReference.playlist;
    final owners = playlist.firstDynamicQuery?.params.owners ?? <String>[];

    final child = owners.isEmpty
        ? PlaylistTitle(
            primaryText: '${playlist.title}',
            secondaryText: playlistData.creator,
            collectionState: null,
            total: playlistDetailsState.total,
          )
        : PlaylistHeaderWithCollectionState(
            primaryText: '${playlist.title}',
            secondaryText: playlistData.creator,
            owners: owners,
            total: playlistDetailsState.total,
          );

    final slidableActions = [
      if (playlistData.playlistReference.type == PlaylistReferenceType.address)
        ..._getAddressSlidableActions(playlistData),
    ];

    if (slidableActions.isEmpty) {
      return child;
    }

    return Slidable(
      groupTag: playlistData.playlistReference.playlist.id.toString(),
      endActionPane: ActionPane(
        extentRatio: 88 / 392,
        motion: const DrawerMotion(),
        children: slidableActions,
      ),
      child: child,
    );
  }

  List<CustomSlidableAction> _getAddressSlidableActions(
      PlaylistData playlistData) {
    return [
      CustomSlidableAction(
        backgroundColor: AppColor.primaryBlack,
        padding: EdgeInsets.zero,
        onPressed: (BuildContext context) async {
          final playlist = playlistData.playlistReference.playlist;
          UIHelper.showDeletePlaylistConfirmation(playlist, (playlist) async {
            await injector<DriftDatabaseService>()
                .deletePlaylistById(playlist.id);
            final isAddressPlaylist = playlist.isAddressPlaylist;
            if (isAddressPlaylist) {
              final address = playlist.addressOwners;
              if (address.isNotEmpty) {
                await injector<UserDp1PlaylistService>()
                    .clearAddressIndexingInfo(addresses: address);
              }
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/images/trash.svg',
                height: 15,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: AppTypography.body(context).white,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}
