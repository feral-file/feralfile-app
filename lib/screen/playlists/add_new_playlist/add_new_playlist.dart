import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/playlists/add_new_playlist/add_new_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/add_new_playlist/add_new_playlist_state.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/token_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/radio_check_box.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/search_bar.dart';
import 'package:autonomy_flutter/view/text_field.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddNewPlaylistScreen extends StatefulWidget {
  const AddNewPlaylistScreen({super.key, this.playListModel});

  final PlayListModel? playListModel;

  @override
  State<AddNewPlaylistScreen> createState() => _AddNewPlaylistScreenState();
}

class _AddNewPlaylistScreenState extends State<AddNewPlaylistScreen>
    with AfterLayoutMixin {
  final bloc = injector.get<AddNewPlaylistBloc>();
  final nftBloc = injector.get<NftCollectionBloc>();
  final _playlistNameC = TextEditingController();
  final _focusNode = FocusNode();
  late bool _isShowSearchBar;

  final _formKey = GlobalKey<FormState>();
  List<AssetToken> tokensPlaylist = [];
  final _controller = ScrollController();
  late String _searchText;
  late String _playlistName;

  @override
  void initState() {
    _searchText = '';
    _playlistName = '';
    _isShowSearchBar = false;
    super.initState();

    _playlistNameC.text = _playlistName;
    _controller
      ..addListener(_scrollListenerToLoadMore)
      ..addListener(_scrollListenerToShowSearchBar);
    refreshTokens();
    nftBloc.add(GetTokensByOwnerEvent(pageKey: PageKey.init()));
    bloc.add(InitPlaylist(playListModel: widget.playListModel));
    WidgetsBinding.instance.addPostFrameCallback((context) {
      _focusCollectionName();
    });
  }

  @override
  void afterFirstLayout(BuildContext context) {}

  void _focusCollectionName() {
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _scrollListenerToLoadMore() {
    if (_controller.position.pixels + 100 >=
        _controller.position.maxScrollExtent) {
      _loadMore();
    }
  }

  void _scrollListenerToShowSearchBar() {
    if (_controller.position.pixels <= 10 &&
        _controller.position.userScrollDirection == ScrollDirection.forward) {
      setState(() {
        _isShowSearchBar = true;
      });
    }
  }

  Future<void> _scrollToTop() async {
    await _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  void _loadMore() {
    final nextKey = nftBloc.state.nextKey;
    if (nextKey == null || nextKey.isLoaded) {
      return;
    }
    nftBloc.add(GetTokensByOwnerEvent(pageKey: nextKey));
  }

  Future<List<String>> getAddresses() async {
    return injector<AddressService>()
        .getAllWalletAddresses()
        .map((e) => e.address)
        .toList();
  }

  void refreshTokens() {
    nftBloc.add(RefreshNftCollectionByOwners());
  }

  @override
  void dispose() {
    _playlistNameC.dispose();
    super.dispose();
  }

  List<CompactedAssetToken> setupPlayList({
    required List<CompactedAssetToken> tokens,
    List<String>? selectedTokens,
  }) {
    tokens = tokens.filterAssetToken().filterByTitleContain(_searchText);
    bloc.state.tokens = tokens;
    if (tokens.length <= INDEXER_TOKENS_MAXIMUM) {
      _loadMore();
    }
    return tokens;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AddNewPlaylistBloc, AddNewPlaylistState>(
      bloc: bloc,
      listener: (context, state) {
        if (state.isAddSuccess == true) {
          Navigator.pop(context, state.playListModel);
        }
      },
      builder: (context, state) {
        final playlistName = _playlistNameC.text;
        final selectedIDs = state.selectedIDs;
        final isDone =
            playlistName.isNotEmpty && selectedIDs?.isNotEmpty == true;
        return Scaffold(
          backgroundColor: AppColor.primaryBlack,
          appBar: getCustomDoneAppBar(
            context,
            title: TextFieldWidget(
              focusNode: _focusNode,
              hintText: 'new_playlist'.tr(),
              controller: _playlistNameC,
              cursorColor: AppColor.white,
              style: theme.textTheme.ppMori400White14,
              hintStyle: theme.textTheme.ppMori400Grey14,
              textAlign: TextAlign.center,
              border: InputBorder.none,
              onFieldSubmitted: (value) {
                setState(() {
                  _playlistName = value;
                });
              },
              onChanged: (value) {
                setState(() {
                  _playlistName = value;
                });
              },
            ),
            isWhite: false,
            onDone: !isDone
                ? null
                : () {
                    final nftState = nftBloc.state;
                    final selectedCount = nftState.tokens.items
                        .where(
                          (element) =>
                              state.selectedIDs?.contains(element.id) ?? false,
                        )
                        .length;
                    if (selectedCount <= 0) {
                      return;
                    }
                    bloc.add(
                      CreatePlaylist(
                        name: _playlistNameC.text.isNotEmpty
                            ? _playlistNameC.text
                            : null,
                      ),
                    );
                  },
            onCancel: () {
              Navigator.pop(context);
            },
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.25),
              child:
                  addOnlyDivider(color: AppColor.auQuickSilver, border: 0.25),
            ),
          ),
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: BlocBuilder<NftCollectionBloc, NftCollectionBlocState>(
              bloc: nftBloc,
              builder: (context, nftState) => SafeArea(
                top: false,
                bottom: false,
                child: Stack(
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (_isShowSearchBar)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                15,
                                20,
                                15,
                                18,
                              ),
                              child: ActionBar(
                                searchBar: AuSearchBar(
                                  onChanged: (value) {},
                                  onSearch: (value) {
                                    setState(() {
                                      _searchText = value;
                                    });
                                  },
                                  onClear: (value) {
                                    setState(() {
                                      _searchText = '';
                                    });
                                  },
                                ),
                                onCancel: () async {
                                  setState(() {
                                    _searchText = '';
                                    _isShowSearchBar = false;
                                  });
                                  await _scrollToTop();
                                },
                              ),
                            ),
                          addOnlyDivider(),
                          Expanded(
                            child: NftCollectionGrid(
                              state: nftState.state,
                              tokens: nftState.tokens
                                  .unique((token) => token.id)
                                  .items,
                              loadingIndicatorBuilder: loadingView,
                              customGalleryViewBuilder: (context, tokens) =>
                                  _assetsWidget(
                                context,
                                setupPlayList(tokens: tokens),
                                onChanged: (tokenID, value) => bloc.add(
                                  UpdateItemPlaylist(
                                    tokenID: tokenID,
                                    value: value,
                                  ),
                                ),
                                selectedTokens: state.selectedIDs,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _assetsWidget(
    BuildContext context,
    List<CompactedAssetToken> tokens, {
    Function(String tokenID, bool value)? onChanged,
    List<String>? selectedTokens,
  }) {
    final cellPerRow =
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
      itemBuilder: (context, index) {
        if (index >= tokens.length) {
          return const SizedBox();
        }
        return ThumbnailPlaylistItem(
          token: tokens[index],
          cachedImageSize: cachedImageSize,
          isSelected: selectedTokens?.contains(tokens[index].id) ?? false,
          onChanged: (value) {
            onChanged?.call(tokens[index].id, value ?? false);
          },
          usingThumbnailID: index > 50,
        );
      },

      /// add 3 blank cells to make space for save button
      itemCount: tokens.length + 3,
    );
  }
}

class ThumbnailPlaylistItem extends StatefulWidget {
  const ThumbnailPlaylistItem({
    required this.token,
    required this.cachedImageSize,
    super.key,
    this.showSelect = true,
    this.isSelected = false,
    this.onChanged,
    this.showTriggerOrder = false,
    this.usingThumbnailID = true,
  });

  final bool showSelect;
  final bool isSelected;
  final CompactedAssetToken token;
  final Function(bool?)? onChanged;
  final int cachedImageSize;
  final bool usingThumbnailID;
  final bool showTriggerOrder;

  @override
  State<ThumbnailPlaylistItem> createState() => _ThumbnailPlaylistItemState();
}

class _ThumbnailPlaylistItemState extends State<ThumbnailPlaylistItem> {
  bool isSelected = false;

  @override
  void initState() {
    super.initState();
    isSelected = widget.isSelected;
  }

  @override
  void didUpdateWidget(covariant ThumbnailPlaylistItem oldWidget) {
    setState(() {
      isSelected = widget.isSelected;
    });
    super.didUpdateWidget(oldWidget);
  }

  void onChanged(bool? value) {
    setState(() {
      isSelected = !isSelected;
      widget.onChanged?.call(isSelected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(isSelected),
      child: Stack(
        children: [
          SizedBox.expand(
            child: tokenGalleryThumbnailWidget(
              context,
              widget.token,
              widget.cachedImageSize,
              usingThumbnailID: widget.usingThumbnailID,
              useHero: false,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Visibility(
              visible: widget.showSelect,
              child: RadioSelectAddress(
                isChecked: isSelected,
                borderColor: theme.colorScheme.secondary,
                onTap: onChanged,
              ),
            ),
          ),
          Visibility(
            visible: widget.showTriggerOrder,
            child: Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Align(
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Container(
                      width: 20,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Container(
                      width: 20,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget loadingView(BuildContext context) {
  final theme = Theme.of(context);
  return Center(
    child: Column(
      children: [
        CircularProgressIndicator(
          backgroundColor: Colors.white60,
          color: theme.colorScheme.secondary,
          strokeWidth: 2,
        ),
      ],
    ),
  );
}
