//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_item_ext.dart';
import 'package:autonomy_flutter/screen/search/widgets/filter_bar.dart';
import 'package:autonomy_flutter/screen/search/widgets/search_bar.dart'
    as search_widgets;
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/view/dp1_playlist_grid_view.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchPagePayload {
  const SearchPagePayload({
    this.autoFocus = false,
  });

  final bool autoFocus;
}

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.payload,
  });

  final SearchPagePayload payload;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final MeiliSearchBloc _bloc;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    try {
      _bloc = context.read<MeiliSearchBloc>();
    } catch (e) {
      _bloc = injector<MeiliSearchBloc>();
    }
    _searchController = TextEditingController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {}

  void _onSearchSubmitted(String query) {
    _bloc.add(MeiliSearchQuerySubmitted(query));
  }

  void _onFilterTypeChanged(SearchFilterType filterType) {
    _bloc.add(MeiliSearchFilterTypeChanged(filterType));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: getBackAppBar(
          context,
          onBack: () => Navigator.pop(context),
          title: 'Search',
          isWhite: false,
          backgroundColor: AppColor.auGreyBackground,
          statusBarColor: AppColor.auGreyBackground,
        ),
        body: BlocBuilder<MeiliSearchBloc, MeiliSearchState>(
          bloc: _bloc,
          builder: (context, state) {
            final resultsContent = Column(
              children: [
                FilterBar(
                  selectedFilterType: state.filterType,
                  onFilterTypeChanged: _onFilterTypeChanged,
                  hasChannels: state.channels.isNotEmpty,
                  hasPlaylists: state.playlists.isNotEmpty,
                  hasItems: state.items.isNotEmpty,
                  hasNftTokens: state.nftTokens.isNotEmpty,
                ),
                Expanded(
                  child: _buildResultsSection(context, state),
                ),
              ],
            );

            final resultsWithOverlay = state.isLoading
                ? Stack(
                    children: [
                      resultsContent,
                      Positioned.fill(
                        child: ColoredBox(
                          color:
                              AppColor.auGreyBackground.withValues(alpha: 0.6),
                          child: const Center(
                            child: LoadingWidget(),
                          ),
                        ),
                      ),
                    ],
                  )
                : resultsContent;

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(
                    LayoutConstants.pageHorizontalDefault,
                  ),
                  child: search_widgets.SearchBar(
                    controller: _searchController,
                    onSubmitted: _onSearchSubmitted,
                    autoFocus: widget.payload.autoFocus,
                  ),
                ),
                Expanded(child: resultsWithOverlay),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildResultsSection(
    BuildContext context,
    MeiliSearchState state,
  ) {
    if (state.hasError) {
      return _buildErrorView(context, state);
    }

    if (!state.hasResults && state.query.isNotEmpty) {
      return _buildEmptyView(context);
    }

    if (state.query.isEmpty) {
      return _buildInitialView(context);
    }

    return _buildResultsView(context, state);
  }

  Widget _buildInitialView(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Search for channels, playlists, or works',
              style: AppTypography.body(context).white,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    final textStyle = AppTypography.body(context).white;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.pageHorizontalDefault),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No results found',
              style: textStyle.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'Try exhibitions, playlists, artists, or curators. Collection search will return soon.',
              style: textStyle,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Examples: Dmitri Cherniak artworks, generative art exhibitions, Maya Man',
              style: textStyle,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Didn\'t find what you wanted? Tap Help to tell us.',
              style: textStyle,
            ),
            SizedBox(height: LayoutConstants.space6),
            PrimaryButton(
              onTap: () {
                injector<NavigationService>().showCustomerSupport();
              },
              text: 'Help',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, MeiliSearchState state) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: LayoutConstants.space12,
              color: AppColor.auGrey,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'We couldn\'t complete your search',
              style: AppTypography.body(context).white,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(BuildContext context, MeiliSearchState state) {
    // Base content: filter client-side based on filterType
    switch (state.filterType) {
      case SearchFilterType.channels:
        return _buildChannelsView(context, state);
      case SearchFilterType.playlists:
        return _buildPlaylistsView(context, state);
      case SearchFilterType.items:
        return _buildItemsView(context, state);
      case SearchFilterType.nftTokens:
        return _buildNftTokensView(context, state);
    }
  }

  Widget _buildChannelsView(BuildContext context, MeiliSearchState state) {
    if (state.channels.isEmpty) {
      return _buildNoResultsForFilterView(context, 'channels');
    }

    final channelReferences = state.channels
        .map((channel) => ChannelReference.fromFeralFileDP1Channel(channel))
        .toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        UIHelper.ChannelSliverListView(
          channelReferences: channelReferences,
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space16),
        ),
      ],
    );
  }

  Widget _buildPlaylistsView(BuildContext context, MeiliSearchState state) {
    if (state.playlists.isEmpty) {
      return _buildNoResultsForFilterView(context, 'playlists');
    }

    final playlistReferences = state.playlists
        .map((playlist) => PlaylistReference.fromFeralFileDP1Call(playlist))
        .toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        UIHelper.playlistSliverListView(playlists: playlistReferences),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space16),
        ),
      ],
    );
  }

  Widget _buildItemsView(BuildContext context, MeiliSearchState state) {
    if (state.items.isEmpty) {
      return _buildNoResultsForFilterView(context, 'works');
    }

    final playlist = DP1CallExtension.fromItems(items: state.items);

    return PlaylistAssetGridView(
      playlist: playlist,
      physics: const AlwaysScrollableScrollPhysics(),
      showLoadingOnUpdating: false,
    );
  }

  Widget _buildNftTokensView(BuildContext context, MeiliSearchState state) {
    if (state.nftTokens.isEmpty) {
      return _buildNoResultsForFilterView(context, 'collections');
    }

    final nowDisplayingItems = state.nftTokens.map((assetToken) {
      final dp1Item =
          DP1PlaylistItemExtension.fromAssetToken(token: assetToken);
      return DP1NowDisplayingItem(dp1Item: dp1Item, assetToken: assetToken);
    }).toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        UIHelper.dp1ItemSliverGrid(context, nowDisplayingItems, 'Collections'),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space16),
        ),
      ],
    );
  }

  Widget _buildNoResultsForFilterView(BuildContext context, String filterType) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LayoutConstants.space6),
        child: Text(
          'No $filterType found',
          style: AppTypography.body(context).white,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
