//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/blockchain.dart';
import 'package:autonomy_flutter/nft_collection/models/models.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/client_token_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/asset_token_ext.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/playlist_ext.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/token_ext.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/cast_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/stream_common_widget.dart';
import 'package:autonomy_flutter/view/title_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

class CollectionHomePage extends StatefulWidget {
  const CollectionHomePage({super.key});

  @override
  State<CollectionHomePage> createState() => CollectionHomePageState();
}

class CollectionHomePageState extends State<CollectionHomePage>
    with
        RouteAware,
        WidgetsBindingObserver,
        AfterLayoutMixin<CollectionHomePage>,
        AutomaticKeepAliveClientMixin {
  StreamSubscription<FGBGType>? _fgbgSubscription;
  late ScrollController _controller;
  int _cachedImageSize = 0;
  final _clientTokenService = injector<ClientTokenService>();
  final _configurationService = injector<ConfigurationService>();
  final _addressService = injector<AddressService>();

  final nftBloc = injector<ClientTokenService>().nftBloc;
  final _identityBloc = injector<IdentityBloc>();
  final _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);
    _controller = ScrollController()..addListener(_scrollListenerToLoadMore);
  }

  void _scrollListenerToLoadMore() {
    if (_controller.position.pixels + 100 >=
        _controller.position.maxScrollExtent) {
      final nextKey = nftBloc.state.nextKey;
      if (nextKey == null || nextKey.isLoaded) {
        return;
      }
      nftBloc.add(GetTokensByOwnerEvent(pageKey: nextKey));
    }
  }

  void _getArtistIdentity(List<CompactedAssetToken> tokens) {
    final needIdentities = tokens.map((e) => e.artistTitle ?? '').toList();
    _identityBloc.add(GetIdentityEvent(needIdentities));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    unawaited(_handleForeground());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    unawaited(_fgbgSubscription?.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Future<void> didPopNext() async {
    super.didPopNext();
  }

  Future<void> _onTokensUpdate(List<CompactedAssetToken> tokens) async {
    //check minted postcard and navigator to artwork detail

    // Check if there is any Tezos token in the list
    final List<String> allAccountNumbers =
        _addressService.getAllWalletAddresses().map((e) => e.address).toList();
    final hashedAddresses = allAccountNumbers.fold(
      0,
      (int previousValue, element) => previousValue + element.hashCode,
    );

    if (_configurationService.sentTezosArtworkMetricValue() !=
            hashedAddresses &&
        tokens.any(
          (asset) => asset.blockchain == Blockchain.TEZOS.name.toLowerCase(),
        )) {
      unawaited(
        _configurationService.setSentTezosArtworkMetric(hashedAddresses),
      );
    }
  }

  List<CompactedAssetToken> _updateTokens(List<CompactedAssetToken> tokens) {
    final filtedTokens = tokens.filterAssetToken();
    final nextKey = nftBloc.state.nextKey;
    if (nextKey != null &&
        !nextKey.isLoaded &&
        filtedTokens.length < COLLECTION_INITIAL_MIN_SIZE) {
      nftBloc.add(GetTokensByOwnerEvent(pageKey: nextKey));
    }
    return filtedTokens;
  }

  String _getDisplayKey() =>
      _updateTokens(nftBloc.state.tokens.items)
          .map((e) => e.id)
          .toList()
          .displayKey ??
      '';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contentWidget =
        BlocConsumer<NftCollectionBloc, NftCollectionBlocState>(
      bloc: nftBloc,
      builder: (context, state) => NftCollectionGrid(
        state: state.state,
        tokens: _updateTokens(state.tokens.items),
        loadingIndicatorBuilder: _loadingView,
        emptyGalleryViewBuilder: _emptyGallery,
        customGalleryViewBuilder: _assetsWidget,
      ),
      listener: (context, state) async {
        log.info('[NftCollectionBloc] State update ${state.tokens.length}');
        if (state.state == NftLoadingState.done) {
          unawaited(_onTokensUpdate(state.tokens.items));
        }
      },
    );
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColor.primaryBlack,
      appBar: getDarkEmptyAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // const NowDisplaying(),
            Expanded(
              child: PrimaryScrollController(
                controller: _controller,
                child: Scaffold(
                  appBar: getFFAppBar(
                    context,
                    onBack: () {
                      Navigator.pop(context);
                    },
                    title: TitleText(
                      title: 'all'.tr(),
                      ellipsis: false,
                      isCentered: true,
                      fontSize: 14,
                    ),
                    action: FFCastButton(
                      // displayKey: _getDisplayKey(),
                      onDeviceSelected: (device) async {
                        log.info('Device selected: ${device.name}');
                        final listTokenIds =
                            _updateTokens(nftBloc.state.tokens.items)
                                .map((e) => e.id)
                                .toList();
                        if (listTokenIds.isEmpty) {
                          log.info('playList is empty');
                          return;
                        }
                        final duration = speedValues.values.first;
                      },
                    ),
                  ),
                  // extendBodyBehindAppBar: true,
                  backgroundColor: AppColor.primaryBlack,
                  body: contentWidget,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingView(BuildContext context) => Center(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + 40,
            ),
            loadingIndicator(valueColor: AppColor.white),
          ],
        ),
      );

  Widget _emptyGallery(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: ResponsiveLayout.getPadding.copyWith(left: 0, right: 0),
      children: [
        SizedBox(
          height: MediaQuery.of(context).padding.top + 40,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Text(
            'collection_empty_now'.tr(),
            //"Your collection is empty for now.",
            style: theme.textTheme.ppMori400White14,
          ),
        ),
      ],
    );
  }

  Widget _assetsWidget(BuildContext context, List<CompactedAssetToken> tokens) {
    final accountIdentities = tokens
        .where((e) => e.pending != true || e.hasMetadata)
        .map((element) => element.identity)
        .toList();
    if (tokens.length <= maxCollectionListSize) {
      _getArtistIdentity(tokens);
    }
    const cellPerRowPhone = 3;
    const cellPerRowTablet = 6;
    const cellSpacing = 3.0;
    final cellPerRow =
        ResponsiveLayout.isMobile ? cellPerRowPhone : cellPerRowTablet;
    if (_cachedImageSize == 0) {
      final estimatedCellWidth =
          MediaQuery.of(context).size.width / cellPerRow -
              cellSpacing * (cellPerRow - 1);
      _cachedImageSize = (estimatedCellWidth * 3).ceil();
    }
    List<Widget> sources;
    sources = [
      SliverToBoxAdapter(
        child: SizedBox(
          height: MediaQuery.of(context).padding.top,
        ),
      ),
      SliverToBoxAdapter(
        child: BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
          bloc: _canvasDeviceBloc,
          builder: (context, canvasDeviceState) {
            final displayKey = _getDisplayKey();
            final isPlaylistCasting =
                canvasDeviceState.lastSelectedActiveDeviceForKey(displayKey) !=
                    null;
            if (isPlaylistCasting) {
              return Padding(
                padding: const EdgeInsets.all(15),
                child: PlaylistControl(
                  displayKey: displayKey,
                ),
              );
            } else {
              return const SizedBox();
            }
          },
        ),
      ),
      if (tokens.length <= maxCollectionListSize) ...[
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 30,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, index) => BlocBuilder<IdentityBloc, IdentityState>(
              bloc: _identityBloc,
              builder: (context, identityState) {
                final artistIdentities = identityState.identityMap;
                return Column(
                  children: [
                    _assetDetailBuilder(
                      context,
                      tokens,
                      index,
                      accountIdentities,
                      artistIdentities,
                    ),
                    const SizedBox(height: 50),
                  ],
                );
              },
            ),
            childCount: tokens.length,
          ),
        ),
      ] else
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cellPerRow,
            crossAxisSpacing: cellSpacing,
            mainAxisSpacing: cellSpacing,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) =>
                _assetBuilder(context, tokens, index, accountIdentities),
            childCount: tokens.length,
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: sources,
      controller: _controller,
    );
  }

  Widget _assetDetailBuilder(
    BuildContext context,
    List<CompactedAssetToken> tokens,
    int index,
    List<ArtworkIdentity> accountIdentities,
    Map<String, String> artistIdentities, {
    String variant = collectionListArtworkThumbnailVariant,
  }) {
    final theme = Theme.of(context);
    final asset = tokens[index];
    final title = asset.displayTitle;
    final artistTitle = asset.artistTitle?.toIdentityOrMask(artistIdentities);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: collectionListArtworkAspectRatio,
          child: _assetBuilder(
            context,
            tokens,
            index,
            accountIdentities,
            variant: variant,
            ratio: collectionListArtworkAspectRatio,
          ),
        ),
        if (title != null && title.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.ppMori400White16,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (artistTitle != null && artistTitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'by'.tr(args: [artistTitle]),
                    style: theme.textTheme.ppMori400White14,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _assetBuilder(
    BuildContext context,
    List<CompactedAssetToken> tokens,
    int index,
    List<ArtworkIdentity> accountIdentities, {
    String variant = 'thumbnail',
    double ratio = 1,
  }) {
    final asset = tokens[index];

    return GestureDetector(
      child: tokenGalleryThumbnailWidget(
        context,
        asset,
        _cachedImageSize,
        // usingThumbnailID: index > 50,
        variant: variant,
        ratio: ratio,
      ),
      onTap: () {
        if (asset.pending == true && !asset.hasMetadata) {
          return;
        }

        final index = tokens
            .where((e) => e.pending != true || e.hasMetadata)
            .toList()
            .indexOf(asset);
        final payload = ArtworkDetailPayload(accountIdentities[index]);

        const pageName = AppRouter.artworkDetailsPage;
        unawaited(
          Navigator.of(context).pushNamed(
            pageName, ////need change to pageName
            arguments: payload,
          ),
        );
      },
    );
  }

  void scrollToTop() {
    unawaited(
      _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      ),
    );
  }

  Future<void> _handleForeBackground(FGBGType event) async {
    switch (event) {
      case FGBGType.foreground:
        unawaited(_handleForeground());
      case FGBGType.background:
    }
  }

  Future<void> _handleForeground() async {
    unawaited(_clientTokenService.refreshTokens(checkPendingToken: true));
  }

  @override
  bool get wantKeepAlive => true;
}
