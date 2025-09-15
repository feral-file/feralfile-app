import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist_state.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/iterable_ext.dart';
import 'package:autonomy_flutter/util/playlist_ext.dart';
import 'package:autonomy_flutter/util/token_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/stream_common_widget.dart';
import 'package:autonomy_flutter/view/title_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

enum CollectionType { manual, medium, artist }

class ViewPlaylistScreenPayload {
  const ViewPlaylistScreenPayload({
    required this.playListModel,
    this.titleIcon,
    this.collectionType = CollectionType.manual,
  });

  final PlayListModel playListModel;
  final CollectionType collectionType;
  final Widget? titleIcon;
}

class ViewPlaylistScreen extends StatefulWidget {
  const ViewPlaylistScreen({required this.payload, super.key});

  final ViewPlaylistScreenPayload payload;

  @override
  State<ViewPlaylistScreen> createState() => _ViewPlaylistScreenState();
}

class _ViewPlaylistScreenState extends State<ViewPlaylistScreen> {
  final _playlistService = injector<PlaylistService>();

  late ViewPlaylistBloc bloc;
  final nftBloc = injector.get<NftCollectionBloc>(param1: false);
  List<ArtworkIdentity> accountIdentities = [];
  List<CompactedAssetToken> tokensPlaylist = [];
  final _focusNode = FocusNode();
  late CanvasDeviceBloc _canvasDeviceBloc;
  late bool editable;

  @override
  void initState() {
    bloc = ViewPlaylistBloc(_playlistService, widget.payload.playListModel);
    editable = widget.payload.collectionType == CollectionType.manual &&
        !widget.payload.playListModel.isDefault;
    super.initState();

    nftBloc.add(
      RefreshNftCollectionByIDs(
        ids: widget.payload.playListModel.tokenIDs,
      ),
    );

    nftBloc.stream.listen((state) {
      final tokens = state.tokens.items;
      setState(() {
        tokensPlaylist = _setupPlayList(
          tokens: tokens,
          selectedTokens: widget.payload.playListModel.tokenIDs,
        );
      });
    });

    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
  }

  Future<void> _deletePlayList() async {
    final isDeleted = await _playlistService.deletePlaylist(
      widget.payload.playListModel,
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
            ?.map(
              (e) =>
                  tokens.where((element) => element.id == e).firstOrDefault(),
            )
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

                  bloc.add(SavePlaylist(playlist: playListModel));
                  nftBloc.add(
                    RefreshNftCollectionByIDs(
                      ids: value.tokenIDs,
                    ),
                  );
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
                  width: 22,
                  height: 22,
                  child: widget.payload.titleIcon,
                ),
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
                padding: EdgeInsets.zero,
                child: SvgPicture.asset(
                  'assets/images/more_circle.svg',
                  width: 22,
                  height: 22,
                ),
              ),
            ),
          ),
        ],
        // if (_getDisplayKey(playList) != null && tokensPlaylist.isNotEmpty) ...[
        //   FFCastButton(
        //     shouldCheckSubscription: playList.requiredPremiumToDisplay,
        //     displayKey: _getDisplayKey(playList)!,
        //     onDeviceSelected: (device) async {
        //       final duration = speedValues.values.first;
        //
        //       final items = tokensPlaylist.map((token) {
        //         return DP1Item(
        //           title: token.title!,
        //           source: token.previewURL!,
        //           duration: duration.inSeconds,
        //           license: ArtworkDisplayLicense.open,
        //         );
        //
        //         // final dp1Playlist = PlaylistDP1Call(
        //         //
        //         // )
        //       }).toList();
        //       final completer = Completer<void>();
        //       _canvasDeviceBloc.add(
        //         CanvasDeviceCastListArtworkEvent(
        //           device,
        //           items,
        //           onDone: () {
        //             completer.complete();
        //           },
        //         ),
        //       );
        //       await completer.future;
        //     },
        //   ),
        //   const SizedBox(width: 15),
        // ],
      ];

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ViewPlaylistBloc, ViewPlaylistState>(
        bloc: bloc,
        listener: (context, state) {},
        builder: (context, state) {
          final playList = state.playListModel;
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
                      appBar: getCustomBackAppBar(
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
                                  displayKey ?? '',
                                );
                                final isPlaylistCasting =
                                    lastSelectedDevice != null;
                                if (isPlaylistCasting) {
                                  return Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: PlaylistControl(
                                      displayKey: displayKey!,
                                      viewingArtworkBuilder: (context, status) {
                                        return const SizedBox();
                                      },
                                    ),
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
                                  tokens: nftState.tokens.items,
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

  Widget _assetsWidget(
    BuildContext context,
    List<CompactedAssetToken> tokens, {
    required List<ArtworkIdentity> accountIdentities,
    required PlayListModel playlist,
  }) {
    final cellPerRow =
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
                    child: tokenGalleryThumbnailWidget(
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
                itemCount: tokens.length,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AddButton extends StatelessWidget {
  const AddButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.iconOnDisabled,
    this.isEnable = true,
  });

  final Widget icon;
  final Widget? iconOnDisabled;
  final void Function() onTap;
  final bool isEnable;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: isEnable ? onTap : null,
        child: isEnable ? icon : iconOnDisabled ?? icon,
      );
}
