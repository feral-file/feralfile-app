import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/collection_pro/collection_pro_bloc.dart';
import 'package:autonomy_flutter/screen/collection_pro/collection_pro_state.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/home/list_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/playlists/list_playlists/list_playlists.dart';
import 'package:autonomy_flutter/screen/playlists/view_playlist/view_playlist.dart';
import 'package:autonomy_flutter/screen/predefined_collection/predefined_collection_screen.dart';
import 'package:autonomy_flutter/screen/wallet/wallet_page.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/collection_ext.dart';
import 'package:autonomy_flutter/util/list_extension.dart';
import 'package:autonomy_flutter/util/predefined_collection_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/galery_thumbnail_item.dart';
import 'package:autonomy_flutter/view/get_started_banner.dart';
import 'package:autonomy_flutter/view/header.dart';
import 'package:autonomy_flutter/view/predefined_collection/predefined_collection_item.dart';
import 'package:autonomy_flutter/view/search_bar.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/predefined_collection_model.dart';

class CollectionPro extends StatefulWidget {
  const CollectionPro({
    required this.tokens,
    required this.scrollController,
    super.key,
  });

  final List<CompactedAssetToken> tokens;
  final ScrollController scrollController;

  @override
  State<CollectionPro> createState() => CollectionProState();
}

class CollectionProState extends State<CollectionPro>
    with RouteAware, WidgetsBindingObserver {
  final _bloc = injector.get<CollectionProBloc>();
  final _identityBloc = injector.get<IdentityBloc>();
  late ScrollController _scrollController;
  late ValueNotifier<String> searchStr;
  late bool isShowSearchBar;
  final GlobalKey<CollectionSectionState> _collectionSectionKey = GlobalKey();
  List<PredefinedCollectionModel> _listPredefinedCollectionByArtist = [];
  List<PredefinedCollectionModel> _listPredefinedCollectionByMedium = [];
  List<CompactedAssetToken> _works = [];
  late bool _isLoaded;
  late bool _showGetStartedBanner = false;
  final _configurationService = injector<ConfigurationService>();

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _isLoaded = false;
    _showGetStartedBanner = _configurationService.getShowAddAddressBanner();
    searchStr = ValueNotifier('');
    searchStr.addListener(loadCollection);
    isShowSearchBar = false;
    _scrollController = widget.scrollController;
    loadCollection();
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didPopNext() {
    loadCollection();
    super.didPopNext();
  }

  void loadCollection() {
    unawaited(refreshCollectionSection());
    _bloc.add(LoadCollectionEvent(filterStr: searchStr.value));
  }

  void fetchIdentities(CollectionLoadedState state) {
    final listPredefinedCollectionByArtist =
        state.listPredefinedCollectionByArtist;
    final neededIdentities = [
      ...?listPredefinedCollectionByArtist?.map((e) => e.id),
    ].whereNotNull().toList().unique()
      ..removeWhere((element) => element == '');

    if (neededIdentities.isNotEmpty) {
      _identityBloc.add(GetIdentityEvent(neededIdentities));
    }
  }

  Future<void> refreshCollectionSection() async {
    final collectionSectionState = _collectionSectionKey.currentState;
    if (collectionSectionState != null) {
      await collectionSectionState.refreshPlaylist();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getDarkEmptyAppBar(Colors.transparent),
        backgroundColor: AppColor.primaryBlack,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: _body(context),
              ),
            ],
          ),
        ),
      );

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'my_collection'.tr(),
              style: theme.textTheme.ppMori700Black36
                  .copyWith(color: AppColor.white),
            ),
          ),
          if (!isShowSearchBar)
            IconButton(
              onPressed: () {
                setState(() {
                  isShowSearchBar = true;
                });
              },
              icon: SvgPicture.asset(
                'assets/images/search.svg',
                width: 24,
                height: 24,
                colorFilter:
                    const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
              ),
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) => BlocConsumer(
        bloc: _bloc,
        listener: (context, state) {
          if (state is CollectionLoadedState) {
            fetchIdentities(state);
            setState(() {
              _listPredefinedCollectionByMedium =
                  state.listPredefinedCollectionByMedium ?? [];
              _works = state.works;
              _isLoaded = true;
            });
          }
        },
        builder: (context, collectionProState) {
          if (collectionProState is CollectionLoadedState) {
            return BlocConsumer<IdentityBloc, IdentityState>(
              listener: (context, identityState) {
                final identityMap = identityState.identityMap
                  ..removeWhere((key, value) => value.isEmpty);
                final listPredefinedCollectionByArtist =
                    (collectionProState.listPredefinedCollectionByArtist ?? [])
                        .map(
                          (e) {
                            var name = e.name ?? e.id;
                            if (name == e.id) {
                              name = name.toIdentityOrMask(identityMap) ??
                                  name.maskOnly(5);
                            }
                            e.name = name;
                            return e;
                          },
                        )
                        .toList()
                        .filterByName(searchStr.value)
                      ..sort((a, b) => a.name.compareSearchKey(b.name));
                setState(() {
                  _listPredefinedCollectionByArtist =
                      listPredefinedCollectionByArtist;
                });
              },
              builder: (context, identityState) {
                final isEmptyView = !_isLoaded ||
                    (_isEmptyCollection(context) && searchStr.value.isEmpty);
                final isSearchEmptyView = _isLoaded &&
                    _isEmptyCollection(context) &&
                    searchStr.value.isNotEmpty;
                final padding = EdgeInsets.symmetric(horizontal: 15);
                return CustomScrollView(
                  controller: _scrollController,
                  shrinkWrap: true,
                  slivers: [
                    // SliverToBoxAdapter(child: NowDisplaying()),
                    SliverToBoxAdapter(
                        child: Padding(
                      padding: padding,
                      child: _header(context),
                    )),
                    SliverToBoxAdapter(child: const SizedBox(height: 20)),
                    if (isShowSearchBar)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: padding,
                          child: FFSearchBar(
                            onChanged: (text) {},
                            onSearch: (text) {
                              setState(() {
                                searchStr.value = text;
                              });
                            },
                            onCancel: () {
                              setState(() {
                                searchStr.value = '';
                                isShowSearchBar = false;
                              });
                            },
                          ),
                        ),
                      ),
                    if (!isEmptyView)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: padding,
                          child: ValueListenableBuilder(
                            valueListenable: searchStr,
                            builder: (
                              BuildContext context,
                              String value,
                              Widget? child,
                            ) =>
                                CollectionSection(
                              key: _collectionSectionKey,
                              filterString: value,
                            ),
                          ),
                        ),
                      ),
                    if (isEmptyView) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: padding,
                          child: Visibility(
                            visible: isEmptyView,
                            child: _emptyView(context),
                          ),
                        ),
                      ),
                    ] else if (isSearchEmptyView) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: padding,
                          child: Visibility(
                            visible: isSearchEmptyView,
                            child: _searchEmptyView(context),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 60),
                      ),
                      if (searchStr.value.isEmpty) ...[
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            _predefinedCollectionByMediumBuilder,
                            childCount:
                                _listPredefinedCollectionByMedium.length + 1,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 60),
                        ),
                      ],
                      if (searchStr.value.isNotEmpty) ...[
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            _worksBuilder,
                            childCount: _works.length + 1,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 60),
                        ),
                      ],
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          _predefinedCollectionByArtistBuilder,
                          childCount:
                              _listPredefinedCollectionByArtist.length + 1,
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ],
                );
              },
              bloc: _identityBloc,
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      );

  bool _isEmptyCollection(BuildContext context) {
    final collection =
        injector<ListPlaylistBloc>().state.playlists.filter(searchStr.value);
    final isEmpty = _listPredefinedCollectionByArtist.isEmpty &&
        _listPredefinedCollectionByMedium.isEmpty &&
        _works.isEmpty &&
        collection.isEmpty;
    return isEmpty;
  }

  Widget _searchEmptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'no_results'.tr(),
      style: theme.textTheme.ppMori400White14,
    );
  }

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'see_your_collection'.tr(),
          style: theme.textTheme.ppMori400White14,
        ),
        const SizedBox(height: 15),
        if (_showGetStartedBanner)
          FeralfileBanner(
            onClose: () async {
              await _hideGetStartedBanner();
            },
            title: 'add_collection_from_address'.tr(),
            onGetStarted: _onGetStarted,
          ),
      ],
    );
  }

  Future<void> _hideGetStartedBanner() async {
    setState(() {
      _showGetStartedBanner = false;
    });
  }

  Future<void> _onGetStarted() async {
    await Navigator.of(context).pushNamed(
      AppRouter.walletPage,
      arguments: const WalletPagePayload(openAddAddress: true),
    );
  }

  Widget _predefinedCollectionByArtistBuilder(BuildContext context, int index) {
    const type = PredefinedCollectionType.artist;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: _predefinedCollectionBuilder(context, index, type),
    );
  }

  Widget _predefinedCollectionByMediumBuilder(BuildContext context, int index) {
    const type = PredefinedCollectionType.medium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: _predefinedCollectionBuilder(context, index, type),
    );
  }

  Widget _worksBuilder(BuildContext context, int index) {
    final sep = addDivider(color: AppColor.auLightGrey);
    if (index == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderView(title: 'works'.tr(), padding: EdgeInsets.zero),
          const SizedBox(
            height: 30,
          ),
          if (searchStr.value.isNotEmpty && _works.isEmpty)
            _searchEmptyView(context),
        ],
      );
    } else {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: SizedBox(
              height: 164,
              child: _artworkItem(context, _works[index - 1]),
            ),
          ),
          sep,
        ],
      );
    }
  }

  PredefinedCollectionModel _getPredefinedCollection(
    int index,
    PredefinedCollectionType type,
  ) {
    switch (type) {
      case PredefinedCollectionType.medium:
        return _listPredefinedCollectionByMedium[index];
      case PredefinedCollectionType.artist:
        return _listPredefinedCollectionByArtist[index];
    }
  }

  Widget _predefinedCollectionBuilder(
    BuildContext context,
    int index,
    PredefinedCollectionType type, {
    Widget? action,
  }) {
    final sep = addOnlyDivider(color: AppColor.auGreyBackground);
    if (index == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _predefinedCollectionHeader(context, type, action: action),
          const SizedBox(
            height: 30,
          ),
          if (searchStr.value.isNotEmpty &&
              _listPredefinedCollectionByArtist.isEmpty &&
              type == PredefinedCollectionType.artist)
            _searchEmptyView(context),
        ],
      );
    } else {
      final predefinedCollection = _getPredefinedCollection(index - 1, type);
      return Column(
        children: [
          PredefinedCollectionItem(
            predefinedCollection: predefinedCollection,
            type: type,
            searchStr: searchStr.value,
          ),
          sep,
        ],
      );
    }
  }

  Widget _predefinedCollectionHeader(
    BuildContext context,
    PredefinedCollectionType type, {
    Widget? action,
  }) {
    final title = type == PredefinedCollectionType.medium
        ? 'medium'.tr()
        : 'artists'.tr();
    return HeaderView(
      title: title,
      padding: EdgeInsets.zero,
      action: action,
    );
  }

  Widget _artworkItem(BuildContext context, CompactedAssetToken token) {
    final theme = Theme.of(context);
    final title = token.displayTitle ?? '';
    final artistName = token.artistName ?? token.artistID ?? '';
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(
          context,
          AppRouter.artworkDetailsPage,
          arguments: ArtworkDetailPayload(
            ArtworkIdentity(token.id, token.owner),
          ),
        );
      },
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: GaleryThumbnailItem(
              assetToken: token,
              onTap: () async {
                await Navigator.pushNamed(
                  context,
                  AppRouter.artworkDetailsPage,
                  arguments: ArtworkDetailPayload(
                    ArtworkIdentity(token.id, token.owner),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 19),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.ppMori400White14,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  artistName,
                  style: theme.textTheme.ppMori400Black14
                      .copyWith(color: AppColor.auLightGrey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionSection extends StatefulWidget {
  const CollectionSection({super.key, this.filterString = ''});

  final String filterString;

  @override
  State<CollectionSection> createState() => CollectionSectionState();
}

class CollectionSectionState extends State<CollectionSection>
    with RouteAware, WidgetsBindingObserver {
  late ValueNotifier<List<PlayListModel>?> _playlists;

  Future<void> _initPlayList() async {
    _playListBloc.add(
      ListPlaylistLoadPlaylist(filter: widget.filterString),
    );
  }

  List<PlayListModel> filterPlaylist(String filterString) =>
      _playlists.value?.filter(filterString) ?? [];

  final _playListBloc = injector<ListPlaylistBloc>();

  @override
  void initState() {
    _playlists = ValueNotifier(null);
    super.initState();
    unawaited(_initPlayList());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(_initPlayList());
    super.didPopNext();
  }

  Future<void> _gotoCreatePlaylist(BuildContext context) async {
    await Navigator.of(context)
        .pushNamed(AppRouter.createPlayListPage)
        .then((value) {
      if (!context.mounted) {
        return;
      }
      if (value != null && value is PlayListModel) {
        _playListBloc.add(ListPlaylistLoadPlaylist());
        Navigator.pushNamed(
          context,
          AppRouter.viewPlayListPage,
          arguments: ViewPlaylistScreenPayload(playListModel: value),
        );
      }
    });
  }

  Future<void> refreshPlaylist() async {
    await _initPlayList();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ListPlaylistBloc, ListPlaylistState>(
        bloc: _playListBloc,
        listener: (context, state) {
          _playlists.value = state.playlists;
        },
        builder: (context, state) {
          final playlists = state.playlists;
          if (playlists.isEmpty) {
            return const SizedBox.shrink();
          }
          final playlistIDsString = playlists.map((e) => e.id).toList().join();
          final playlistKeyBytes = utf8.encode(playlistIDsString);
          final playlistKey = sha256.convert(playlistKeyBytes).toString();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListPlaylistsScreen(
                key: Key(playlistKey),
                playlists: _playlists,
                filter: widget.filterString,
                onReorder: (oldIndex, newIndex) {},
                onAdd: () async {
                  await _gotoCreatePlaylist(context);
                },
              ),
            ],
          );
        },
      );
}
