//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/meili_search/widgets/meili_search_result_section.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/dp1_playlist_grid_view.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MeiliSearchPage extends StatefulWidget {
  const MeiliSearchPage({super.key});

  @override
  State<MeiliSearchPage> createState() => _MeiliSearchPageState();
}

class _MeiliSearchPageState extends State<MeiliSearchPage> {
  late final MeiliSearchBloc _bloc;
  late final TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

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
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {}

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: BlocBuilder<MeiliSearchBloc, MeiliSearchState>(
              bloc: _bloc,
              builder: (context, state) {
                if (state.isLoading && !state.hasResults) {
                  return Column(
                    children: [
                      LoadingWidget(),
                    ],
                  );
                }

                if (state.hasError) {
                  return _searchErrorView(context, state);
                }

                if (!state.hasResults && state.query.isNotEmpty) {
                  return _searchEmptyView(context);
                }

                return CustomScrollView(
                  shrinkWrap: true,
                  controller: _scrollController,
                  slivers: [
                    ..._buildOrderedSections(context, state),
                    // if (state.isLoading)
                    //   const SliverPadding(
                    //     padding: EdgeInsets.all(16.0),
                    //     sliver: SliverToBoxAdapter(
                    //       child: Center(child: LoadingWidget()),
                    //     ),
                    //   ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 250),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.ppMori400White16,
          ),
        ],
      ),
    );
  }

  Widget _searchErrorView(BuildContext context, MeiliSearchState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColor.auGrey,
          ),
          const SizedBox(height: 16),
          Text(
            'Search Error',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            state.errorMessage ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _bloc.add(MeiliSearchQueryChanged([state.query]));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsSliver(BuildContext context, MeiliSearchState state) {
    final channels = state.channels;
    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Channels',
        key: ValueKey('channels_${state.hashCode}'),
        builder: (context) {
          return CustomScrollView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              UIHelper.ChannelSliverListView(channels: channels),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsSliver(BuildContext context, MeiliSearchState state) {
    final playlists = state.playlists;
    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Playlists',
        key: ValueKey('playlists_${state.hashCode}'),
        builder: (context) {
          return CustomScrollView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              UIHelper.PlaylistSliverListView(playlists: playlists),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItemsSliver(BuildContext context, MeiliSearchState state) {
    final items = state.items;
    final playlist = DP1CallExtension.fromItems(items: items);

    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Items',
        builder: (context) {
          return PlaylistAssetGridView(
            playlist: playlist,
            physics: const NeverScrollableScrollPhysics(),
            showLoadingOnUpdating: false,
          );
        },
      ),
    );
  }

  List<Widget> _buildOrderedSections(
      BuildContext context, MeiliSearchState state) {
    final sections = <_SectionEntry>[];
    if (state.channels.isNotEmpty) {
      sections.add(_SectionEntry(
          'Channels',
          state.channelsTopScore,
          (ctx) => SliverPadding(
                padding: EdgeInsets.zero,
                sliver: _buildChannelsSliver(ctx, state),
              )));
    }
    if (state.playlists.isNotEmpty) {
      sections.add(_SectionEntry(
          'Playlists',
          state.playlistsTopScore,
          (ctx) => SliverPadding(
                padding: EdgeInsets.zero,
                sliver: _buildPlaylistsSliver(ctx, state),
              )));
    }
    if (state.items.isNotEmpty) {
      sections.add(_SectionEntry(
          'Items',
          state.itemsTopScore,
          (ctx) => SliverPadding(
                padding: EdgeInsets.zero,
                sliver: _buildItemsSliver(ctx, state),
              )));
    }

    sections.sort((a, b) => b.topScore.compareTo(a.topScore));

    final widgets = <Widget>[];
    for (final s in sections) {
      widgets.add(s.builder(context));
      widgets.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
    }

    return widgets;
  }
}

class _SectionEntry {
  final String name;
  final double topScore;
  final Widget Function(BuildContext) builder;
  _SectionEntry(this.name, this.topScore, this.builder);
}
