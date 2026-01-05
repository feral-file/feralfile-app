import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist_state.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/playlist_service.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/iterable_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/playlist_ext.dart';
import 'package:autonomy_flutter/util/token_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/stream_common_widget.dart';
import 'package:autonomy_flutter/view/title_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

enum CollectionType { manual, medium, artist, featured }

class ViewPlaylistScreenPayload {
  final PlayListModel? playListModel;
  final CollectionType collectionType;
  final Widget? titleIcon;

  const ViewPlaylistScreenPayload(
      {this.playListModel,
      this.titleIcon,
      this.collectionType = CollectionType.manual});
}

class ViewPlaylistScreen extends StatefulWidget {
  final ViewPlaylistScreenPayload payload;

  const ViewPlaylistScreen({required this.payload, super.key});

  @override
  State<ViewPlaylistScreen> createState() => _ViewPlaylistScreenState();
}

class _ViewPlaylistScreenState extends State<ViewPlaylistScreen> {
  final bloc = injector.get<ViewPlaylistBloc>();
  final nftBloc = injector.get<NftCollectionBloc>(param1: false);
  final _playlistService = injector<PlaylistService>();
  List<ArtworkIdentity> accountIdentities = [];
  List<CompactedAssetToken> tokensPlaylist = [];
  final _focusNode = FocusNode();
  late CanvasDeviceBloc _canvasDeviceBloc;
  late bool editable;

  final List<CompactedAssetToken> _featureTokens = [];

  @override
  void initState() {
    editable = widget.payload.collectionType == CollectionType.manual &&
        !(widget.payload.playListModel?.isDefault ?? true);
    super.initState();

    if (widget.payload.collectionType == CollectionType.featured) {
      unawaited(_fetchFeaturedTokens());
    } else {
      nftBloc.add(RefreshNftCollectionByIDs(
        ids: widget.payload.playListModel?.tokenIDs,
      ));
    }

    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
    bloc.add(GetPlayList(playListModel: widget.payload.playListModel));
  }

  Future<void> _fetchFeaturedTokens() async {
    final tokens = await injector<TokensService>()
        .fetchManualTokens(widget.payload.playListModel?.tokenIDs ?? []);
    setState(() {
      _featureTokens
          .addAll(tokens.map((e) => CompactedAssetToken.fromAssetToken(e)));
      log.info('feature tokens: ${_featureTokens.length}');
    });
  }

  Future<void> _deletePlayList() async {
    if (widget.payload.playListModel == null) {
      return;
    }
    final isDeleted = await _playlistService.deletePlaylist(
      widget.payload.playListModel!,
    );
    if (isDeleted) {
      injector<NavigationService>().popUntilHomeOrSettings();
    }
  }

  List<CompactedAssetToken> _setupPlayList({
    required List<CompactedAssetToken> tokens,
    List<String>? selectedTokens,
  }) {
    tokens = tokens.filterAssetToken();

    final temp = selectedTokens
            ?.map((e) =>
                tokens.where((element) => element.id == e).firstOrDefault())
            .toList() ??
        []
      ..removeWhere((element) => element == null);

    tokensPlaylist = List.from(temp);

    accountIdentities = tokensPlaylist
        .where((e) => e.pending != true || e.hasMetadata)
        .map((element) => ArtworkIdentity(element.id, element.owner))
        .toList();
    return tokensPlaylist;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onMoreTap(BuildContext context, PlayListModel playList) async {
    final theme = Theme.of(context);
    await UIHelper.showDrawerAction(
      context,
      options: [
        if (playList.isEditable)
          OptionItem(
            title: 'edit_collection'.tr(),
            icon: SvgPicture.asset(
              'assets/images/rename_icon.svg',
              width: 24,
            ),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.pushNamed(
                context,
                AppRouter.editPlayListPage,
                arguments: playList.copyWith(
                  tokenIDs: playList.tokenIDs.toList(),
                ),
              ).then((value) {
                if (value != null) {
                  final playListModel = value as PlayListModel;
                  bloc.state.playListModel?.tokenIDs = playListModel.tokenIDs;
                  bloc.add(SavePlaylist(name: playListModel.name));
                  nftBloc.add(RefreshNftCollectionByIDs(
                    ids: value.tokenIDs,
                  ));
                }
              });
            },
          ),
        OptionItem(
          title: 'delete_collection'.tr(),
          icon: SvgPicture.asset(
            'assets/images/delete_icon.svg',
            width: 24,
          ),
          onTap: () {
            Navigator.pop(context);
            UIHelper.showMessageActionNew(
              context,
              'delete_playlist'.tr(),
              '',
              descriptionWidget: Text(
                playList.source == PlayListSource.activation
                    ? 'delete_activation_playlist_desc'.tr()
                    : 'delete_playlist_desc'.tr(),
                style: theme.textTheme.ppMori400White14,
              ),
              actionButton: 'remove_collection'.tr(),
              onAction: _deletePlayList,
            );
          },
        ),
        OptionItem(),
      ],
    );
  }

  Widget _appBarTitle(BuildContext context, PlayListModel playList) =>
      widget.payload.titleIcon != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 22, height: 22, child: widget.payload.titleIcon),
                const SizedBox(width: 10),
                _getTitle(playList),
              ],
            )
          : _getTitle(playList);

  Widget _getTitle(PlayListModel playList) => TitleText(
        title: playList.getName(),
        fontSize: 14,
        ellipsis: false,
        isCentered: true,
      );

  List<Widget> _appBarAction(BuildContext context, PlayListModel playList) => [
        if (editable) ...[
          const SizedBox(width: 5),
          Semantics(
            label: 'artworkDotIcon',
            child: IconButton(
              onPressed: () async => _onMoreTap(context, playList),
              constraints: const BoxConstraints(
                maxWidth: 44,
                maxHeight: 44,
                minWidth: 44,
                minHeight: 44,
              ),
              icon: Padding(
                padding: const EdgeInsets.all(0),
                child: SvgPicture.asset(
                  'assets/images/more_circle.svg',
                  width: 22,
                  height: 22,
                ),
              ),
            ),
          ),
        ],
      ];

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ViewPlaylistBloc, ViewPlaylistState>(
        bloc: bloc,
        listener: (context, state) {},
        builder: (context, state) {
          if (state.playListModel == null) {
            return const SizedBox();
          }

          final PlayListModel playList = state.playListModel!;
          return Scaffold(
            backgroundColor: AppColor.primaryBlack,
            appBar: getDarkEmptyAppBar(),
            extendBody: true,
            body: SafeArea(
              child: Column(
                children: [
                  // const NowDisplaying(),
                  Expanded(
                    child: Scaffold(
                      backgroundColor: AppColor.primaryBlack,
                      appBar: getPlaylistAppBar(
                        context,
                        title: _appBarTitle(context, playList),
                        actions: _appBarAction(context, playList),
                        adjustLeftTitleWith: 56,
                      ),
                      body: BlocBuilder<NftCollectionBloc,
                          NftCollectionBlocState>(
                        bloc: nftBloc,
                        builder: (context, nftState) => Column(
                          children: [
                            BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
                              bloc: _canvasDeviceBloc,
                              builder: (context, canvasDeviceState) {
                                final displayKey = _getDisplayKey(playList);
                                final lastSelectedDevice = canvasDeviceState
                                    .lastSelectedActiveDeviceForKey(
                                        displayKey ?? '');
                                final isPlaylistCasting =
                                    lastSelectedDevice != null;
                                if (isPlaylistCasting) {
                                  return Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: PlaylistControl(
                                        displayKey: displayKey!,
                                        viewingArtworkBuilder:
                                            (context, status) {
                                          final status = canvasDeviceState
                                                  .canvasDeviceStatus[
                                              lastSelectedDevice.deviceId];
                                          if (status == null) {
                                            return const SizedBox();
                                          }
                                          return _viewingArtworkWidget(
                                            context,
                                            tokensPlaylist,
                                            status,
                                          );
                                        }),
                                  );
                                } else {
                                  return const SizedBox();
                                }
                              },
                            ),
                            Expanded(
                              child: NftCollectionGrid(
                                state: nftState.state,
                                tokens: _setupPlayList(
                                  tokens: widget.payload.collectionType ==
                                          CollectionType.featured
                                      ? _featureTokens
                                      : nftState.tokens.items,
                                  selectedTokens: playList.tokenIDs,
                                ),
                                customGalleryViewBuilder: (context, tokens) =>
                                    _assetsWidget(
                                  context,
                                  tokens,
                                  accountIdentities: accountIdentities,
                                  playlist: playList,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

  String? _getDisplayKey(PlayListModel playList) => playList.displayKey;

  Widget _viewingArtworkWidget(BuildContext context,
      List<CompactedAssetToken> assetTokens, CheckCastingStatusReply status) {
    return const SizedBox();
    // return const NowDisplaying();
  }

  Widget _assetsWidget(
    BuildContext context,
    List<CompactedAssetToken> tokens, {
    required List<ArtworkIdentity> accountIdentities,
    required PlayListModel playlist,
  }) {
    int cellPerRow =
        ResponsiveLayout.isMobile ? cellPerRowPhone : cellPerRowTablet;

    final estimatedCellWidth = MediaQuery.of(context).size.width / cellPerRow -
        cellSpacing * (cellPerRow - 1);
    final cachedImageSize = (estimatedCellWidth * 3).ceil();
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cellPerRow,
                    crossAxisSpacing: cellSpacing,
                    mainAxisSpacing: cellSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final asset = tokens[index];
                    return GestureDetector(
                      child: asset.pending == true && !asset.hasMetadata
                          ? PendingTokenWidget(
                              thumbnail: asset.galleryThumbnailURL,
                              tokenId: asset.tokenId,
                              shouldRefreshCache:
                                  asset.shouldRefreshThumbnailCache,
                            )
                          : tokenGalleryThumbnailWidget(
                              context,
                              asset,
                              cachedImageSize,
                              usingThumbnailID: index > 50,
                              useHero: false,
                            ),
                      onTap: () async {
                        if (asset.pending == true && !asset.hasMetadata) {
                          return;
                        }

                        final index = tokens
                            .where((e) => e.pending != true || e.hasMetadata)
                            .toList()
                            .indexOf(asset);

                        final payload = ArtworkDetailPayload(
                          accountIdentities[index],
                          playlist: playlist,
                        );
                        const pageName = AppRouter.artworkDetailsPage;

                        await Navigator.of(context)
                            .pushNamed(pageName, arguments: payload);
                      },
                    );
                  },
                  itemCount: tokens.length),
            ),
          ],
        ),
      ],
    );
  }
}

class AddButton extends StatelessWidget {
  final Widget icon;
  final Widget? iconOnDisabled;
  final void Function() onTap;
  final bool isEnable;

  const AddButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.iconOnDisabled,
    this.isEnable = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: isEnable ? onTap : null,
      child: isEnable ? icon : iconOnDisabled ?? icon);
}
