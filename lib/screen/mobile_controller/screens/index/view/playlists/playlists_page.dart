import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/view/record_controller.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/all_playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_title.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/notice-banner/notice_banner.dart';
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
  late final UserAllOwnCollectionBloc _userAllOwnCollectionBloc;

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
    _userAllOwnCollectionBloc = injector<UserAllOwnCollectionBloc>();
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
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space12),
        ),
        SliverToBoxAdapter(child: _buildCuratedPlaylists()),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space12),
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

    Widget? emptyView;
    Widget? Function(PlaylistData playlistData)? playlistHeaderBuilder;
    if (playlistType == PlaylistType.me) {
      emptyView = Column(
        children: [
          SizedBox(height: 12),
          Padding(
            padding: ResponsiveLayout.pageHorizontalEdgeInsets,
            child: NoticeBanner(
              message: '''
      Type or paste an address into the command bar to load''',
              onTap: () {
                injector<NavigationService>().popToRouteOrPush(
                  AppRouter.voiceCommandPage,
                  arguments: RecordControllerScreenPayload(
                    isListening: false,
                  ),
                );
              },
            ),
          ),
        ],
      );

      playlistHeaderBuilder = _mePlaylistHeaderBuilder;
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
      emptyView: emptyView,
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

  Widget _mePlaylistHeaderBuilder(PlaylistData playlistData) {
    final playlistReference = playlistData.playlistReference;
    final playlist = playlistReference.playlist;
    final owners = playlist.firstDynamicQuery?.params.owners ?? <String>[];

    return BlocBuilder<UserAllOwnCollectionBloc, UserAllOwnCollectionState>(
      bloc: _userAllOwnCollectionBloc,
      builder: (context, collectionState) {
        final theme = Theme.of(context);
        String stateSuffix = '';

        if (owners.isNotEmpty) {
          final targetAddress = owners.first;
          AddressState? targetState;

          for (final addressState in collectionState.addressStates) {
            if (addressState.address.address == targetAddress) {
              targetState = addressState;
              break;
            }
          }

          stateSuffix = targetState?.state.description ?? '';
        }

        final child = PlaylistTitle(
          primaryText: '${playlist.title}' +
              (stateSuffix.isNotEmpty ? ' ($stateSuffix)' : ''),
          secondaryText: playlistData.creator,
        );

        final slidableActions = [
          if (playlistData is AddressPlaylistData)
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
      },
    );
  }

  List<CustomSlidableAction> _getAddressSlidableActions(
      AddressPlaylistData playlistData) {
    return [
      CustomSlidableAction(
        backgroundColor: AppColor.primaryBlack,
        padding: EdgeInsets.zero,
        onPressed: (BuildContext context) async {
          final address = playlistData.address;
          UIHelper.showDeleteAccountConfirmation(address, (address) async {
            await injector<AddressService>().deleteAddress(address);
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
