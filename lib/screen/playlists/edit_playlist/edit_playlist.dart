import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/playlists/add_new_playlist/add_new_playlist.dart';
import 'package:autonomy_flutter/screen/playlists/edit_playlist/edit_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/edit_playlist/edit_playlist_state.dart';
import 'package:autonomy_flutter/screen/playlists/edit_playlist/widgets/edit_playlist_gridview.dart';
import 'package:autonomy_flutter/screen/playlists/edit_playlist/widgets/text_name_playlist.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/iterable_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/token_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/search_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class EditPlaylistScreen extends StatefulWidget {
  final PlayListModel? playListModel;

  const EditPlaylistScreen({super.key, this.playListModel});

  @override
  State<EditPlaylistScreen> createState() => _EditPlaylistScreenState();
}

class _EditPlaylistScreenState extends State<EditPlaylistScreen> {
  final bloc = injector.get<EditPlaylistBloc>();
  final nftBloc = injector.get<NftCollectionBloc>(param1: false);
  List<CompactedAssetToken> tokensPlaylist = [];
  final _focusNode = FocusNode();
  late bool _showSearchBar;
  late String _searchText;
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _showSearchBar = false;
    _searchText = '';
    _controller = ScrollController();
    _controller.addListener(_scrollListenerToShowSearchBar);
    nftBloc.add(RefreshNftCollectionByIDs(ids: widget.playListModel?.tokenIDs));
    bloc.add(InitPlayList(
      playListModel: widget.playListModel,
    ));
  }

  final _playlistService = injector<PlaylistService>();

  Future<void> deletePlayList() async {
    if (widget.playListModel == null) {
      return;
    }
    final isSuccess =
        await _playlistService.deletePlaylist(widget.playListModel!);
    if (isSuccess) {
      injector<NavigationService>().popUntilHomeOrSettings();
    }
  }

  List<CompactedAssetToken> setupPlayList({
    required List<CompactedAssetToken> tokens,
    List<String>? tokenIDs,
  }) {
    tokens = tokens.filterAssetToken().filterByTitleContain(_searchText);

    final temp = tokenIDs
            ?.map((e) =>
                tokens.where((element) => element.id == e).firstOrDefault())
            .toList() ??
        []
      ..removeWhere((element) => element == null);
    tokensPlaylist = List.from(temp);

    return tokensPlaylist;
  }

  void _scrollListenerToShowSearchBar() {
    if (_controller.position.pixels <= 10 &&
        _controller.position.userScrollDirection == ScrollDirection.forward) {
      setState(() {
        _showSearchBar = true;
      });
    }
  }

  Future<void> _scrollToTop() async {
    await _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void onSave(PlayListModel? playList) {
    final thumbnailUrl = tokensPlaylist
        .where((element) => element.id == playList?.tokenIDs.firstOrDefault())
        .firstOrDefault()
        ?.getGalleryThumbnailUrl();
    playList?.thumbnailURL = thumbnailUrl;
    bloc.add(SavePlaylist());
  }

  Widget _assetsWidget(
    BuildContext context,
    List<CompactedAssetToken> tokens, {
    Function(String tokenID, bool value)? onChanged,
    List<String>? selectedTokens,
  }) {
    int cellPerRow =
        ResponsiveLayout.isMobile ? cellPerRowPhone : cellPerRowTablet;

    final estimatedCellWidth = MediaQuery.of(context).size.width / cellPerRow -
        cellSpacing * (cellPerRow - 1);
    final cachedImageSize = (estimatedCellWidth * 3).ceil();

    return GridView.builder(
      controller: _controller,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cellPerRow,
        crossAxisSpacing: cellSpacing,
        mainAxisSpacing: cellSpacing,
      ),
      itemBuilder: (context, index) => ThumbnailPlaylistItem(
        token: tokens[index],
        cachedImageSize: cachedImageSize,
        isSelected: selectedTokens?.contains(tokens[index].id) ?? false,
        onChanged: (value) {
          onChanged?.call(tokens[index].id, value ?? false);
        },
        usingThumbnailID: index > 50,
      ),
      itemCount: tokens.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<EditPlaylistBloc, EditPlaylistState>(
      bloc: bloc,
      listener: (context, state) async {
        if (state.isAddSuccess ?? false) {
          Navigator.pop(context, state.playListModel);
        }
      },
      builder: (context, state) {
        final playList = state.playListModel;
        final selectedItem = state.selectedItem ?? [];

        return Scaffold(
          backgroundColor: AppColor.primaryBlack,
          appBar: getCustomBackAppBar(context,
              title: FFTextName(
                focusNode: _focusNode,
                title: playList?.getName() ?? '',
                onSubmit: (value) {
                  bloc.add(UpdateNamePlaylist(name: value));
                },
              ),
              actions: [
                GestureDetector(
                  onTap: () {
                    onSave(playList);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 15),
                    child: Text(
                      tr('done').capitalize(),
                      style: theme.textTheme.ppMori400White14,
                    ),
                  ),
                ),
              ]),
          body: SafeArea(
            bottom: false,
            child: Stack(
              alignment: Alignment.center,
              children: [
                BlocConsumer<NftCollectionBloc, NftCollectionBlocState>(
                  bloc: nftBloc,
                  builder: (context, nftState) => NftCollectionGrid(
                    state: nftState.state,
                    tokens: nftState.tokens.items,
                    loadingIndicatorBuilder: loadingView,
                    customGalleryViewBuilder: (gridContext, tokens) {
                      final listToken = setupPlayList(
                        tokens: tokens,
                        tokenIDs: playList?.tokenIDs ?? [],
                      );
                      return Column(
                        children: [
                          if (listToken.isEmpty)
                            Padding(
                                padding: const EdgeInsets.only(
                                    left: 14, right: 14, top: 24, bottom: 15),
                                child: tokenEmptyAction(theme, playList)),
                          if (_showSearchBar)
                            Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(15, 20, 15, 18),
                                  child: ActionBar(
                                    searchBar: AuSearchBar(
                                      onChanged: (text) {
                                        setState(() {
                                          _searchText = text;
                                        });
                                      },
                                    ),
                                    onCancel: () async {
                                      setState(() {
                                        _searchText = '';
                                        _showSearchBar = false;
                                      });
                                      await _scrollToTop();
                                    },
                                  ),
                                ),
                                addOnlyDivider(),
                              ],
                            ),
                          if (_showSearchBar)
                            Expanded(
                              child: _assetsWidget(
                                context,
                                listToken,
                                onChanged: (tokenID, value) => bloc.add(
                                  UpdateSelectedPlaylist(
                                    tokenID: tokenID,
                                    value: value,
                                  ),
                                ),
                                selectedTokens: selectedItem,
                              ),
                            )
                          else
                            Expanded(
                              child: EditPlaylistGridView(
                                controller: _controller,
                                onAddTap: () async => Navigator.pushNamed(
                                  context,
                                  AppRouter.createPlayListPage,
                                  arguments: playList,
                                ).then((value) {
                                  if (value != null && value is PlayListModel) {
                                    bloc.add(SavePlaylist());
                                  }
                                }),
                                tokens: listToken,
                                onReorder: (tokens) {
                                  final tokenIDs =
                                      tokens.map((e) => e?.id ?? '').toList();
                                  bloc.add(
                                    UpdateOrderPlaylist(
                                      tokenIDs: tokenIDs,
                                      thumbnailURL: tokens
                                          .where((element) =>
                                              element?.id ==
                                              tokenIDs.firstOrDefault())
                                          .firstOrDefault()
                                          ?.getGalleryThumbnailUrl(),
                                    ),
                                  );
                                },
                                selectedTokens: selectedItem,
                                onChangedSelect: (tokenID, value) => bloc.add(
                                  UpdateSelectedPlaylist(
                                    tokenID: tokenID,
                                    value: value,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  listener: (context, nftState) {},
                ),
                BlocBuilder<NftCollectionBloc, NftCollectionBlocState>(
                  bloc: nftBloc,
                  builder: (context, nftState) => Positioned(
                    bottom: 30,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColor.auGreyBackground,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 12),
                            AddButton(
                              icon: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.all(13),
                                child: SvgPicture.asset(
                                  'assets/images/joinFile.svg',
                                  width: 24,
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                      AppColor.white, BlendMode.srcIn),
                                ),
                              ),
                              onTap: () async {
                                await moveToAddNftToCollection(context);
                              },
                            ),
                            AddButton(
                              icon: Container(
                                color: Colors.transparent,
                                padding: const EdgeInsets.all(13),
                                child: SvgPicture.asset(
                                  'assets/images/rename_icon.svg',
                                  width: 24,
                                  height: 24,
                                  colorFilter: const ColorFilter.mode(
                                      AppColor.white, BlendMode.srcIn),
                                ),
                              ),
                              onTap: () async {
                                _editPlaylistName();
                              },
                            ),
                            GestureDetector(
                              onTap: selectedItem.isEmpty
                                  ? null
                                  : () async {
                                      await _removeSelectedToken(
                                        context,
                                        selectedItem: selectedItem,
                                        playlist: playList!,
                                      );
                                    },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                      color: Colors.transparent,
                                      padding: const EdgeInsets.all(13),
                                      child: selectedItem.isNotEmpty
                                          ? SvgPicture.asset(
                                              'assets/images/trash_white.svg',
                                              width: 24,
                                              height: 24,
                                            )
                                          : SvgPicture.asset(
                                              'assets/images/trash_disable.svg',
                                              width: 24,
                                              height: 24,
                                            )),
                                  if (selectedItem.isNotEmpty) ...[
                                    Container(
                                      height: 14,
                                      width: 14 +
                                          (selectedItem.length > 9 ? 3 : 0),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      padding:
                                          const EdgeInsets.fromLTRB(3, 2, 3, 4),
                                      child: Center(
                                        child: Text(
                                          getTextNumber(selectedItem.length),
                                          style: theme
                                              .textTheme.ppMori400White12
                                              .copyWith(fontSize: 8),
                                        ),
                                      ),
                                    )
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
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
  }

  String getTextNumber(int num) => num > 9 ? '+9' : '$num';

  Future<void> moveToAddNftToCollection(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      AppRouter.addToCollectionPage,
      arguments: bloc.state.playListModel?.copyWith(
        tokenIDs: bloc.state.playListModel?.tokenIDs,
      ),
    ).then((value) {
      if (value != null && value is PlayListModel) {
        bloc.state.playListModel = bloc.state.playListModel?.copyWith(
          tokenIDs: value.tokenIDs.toList(),
          name: value.name,
        );
        bloc.add(UpdateNamePlaylist(name: value.name ?? ''));
        nftBloc.add(RefreshNftCollectionByIDs(
          ids: value.tokenIDs,
        ));
      }
    });
  }

  Future<void> _removeSelectedToken(BuildContext context,
      {required List<String> selectedItem,
      required PlayListModel playlist}) async {
    final theme = Theme.of(context);
    return selectedItem.isEmpty
        ? null
        : await UIHelper.showMessageActionNew(
            context,
            tr('remove_from_list'),
            '',
            descriptionWidget: RichText(
              textScaler: MediaQuery.textScalerOf(context),
              text: TextSpan(
                children: [
                  TextSpan(
                    style: theme.textTheme.ppMori400White16,
                    text: '${'you_are_about_to_remove'.tr()} ',
                  ),
                  TextSpan(
                    style: theme.textTheme.ppMori700White16,
                    text: tr(
                      selectedItem.length != 1 ? 'artworks' : 'artwork',
                      args: [selectedItem.length.toString()],
                    ),
                  ),
                  TextSpan(
                    style: theme.textTheme.ppMori400White16,
                    text: ' ${'from_the_playlist'.tr()} ',
                  ),
                  TextSpan(
                    style: theme.textTheme.ppMori700White16,
                    text: playlist.name ?? tr('untitled'),
                  ),
                  TextSpan(
                    style: theme.textTheme.ppMori400White16,
                    text: 'they_will_remain'.tr(),
                  ),
                ],
              ),
            ),
            actionButton: 'remove'.tr(),
            onAction: () {
              Navigator.pop(context);
              bloc.add(
                RemoveTokens(
                  tokenIDs: selectedItem,
                ),
              );
            },
          );
  }

  void _editPlaylistName() {
    _focusNode.requestFocus();
  }

  Widget tokenEmptyAction(ThemeData theme, PlayListModel? playList) => Row(
        children: [
          Text(
            tr('no_artwork_in_this_playlist'),
            style: theme.textTheme.ppMori400Black12,
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(
                context,
                AppRouter.createPlayListPage,
                arguments: playList,
              ).then((value) {
                if (value != null && value is PlayListModel) {
                  bloc.add(SavePlaylist());
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(64),
              ),
              child: Text(
                tr('add'),
                style: theme.textTheme.ppMori400White12,
              ),
            ),
          )
        ],
      );
}
