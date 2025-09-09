//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/screen/feralfile_home/artwork_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_alumni_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_exhibition_view.dart';
import 'package:autonomy_flutter/screen/meili_search/meili_search_bloc.dart';
import 'package:autonomy_flutter/screen/meili_search/widgets/meili_search_result_section.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/responsive.dart';
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
    _bloc = injector<MeiliSearchBloc>();
    _searchController = TextEditingController();

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _bloc.close();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // if (_scrollController.position.pixels >=
    //     _scrollController.position.maxScrollExtent - 200) {
    //   _bloc.add(MeiliSearchLoadMore());
    // }
  }

  void _onSearchChanged(String query) {
    // Cancel the previous timer if it exists
    _debounceTimer?.cancel();

    // Start a new timer with 50ms delay
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _bloc.add(MeiliSearchQueryChanged(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: BlocBuilder<MeiliSearchBloc, MeiliSearchState>(
                    builder: (context, state) {
                      if (state.isLoading && state.query.isEmpty) {
                        return const Center(
                          child: LoadingWidget(),
                        );
                      }

                      if (state.hasError) {
                        return _searchErrorView(context, state);
                      }

                      if (!state.hasResults && state.query.isNotEmpty) {
                        return _searchEmptyView(context);
                      }

                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverPadding(
                            padding: ResponsiveLayout.pageEdgeInsets,
                            sliver: _buildExhibitionsSliver(context, state),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          SliverPadding(
                            padding: ResponsiveLayout.pageEdgeInsets,
                            sliver: _buildCuratorsSliver(context, state),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          SliverPadding(
                            padding: ResponsiveLayout.pageEdgeInsets,
                            sliver: _buildArtistsSliver(context, state),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          SliverPadding(
                            padding: ResponsiveLayout.pageEdgeInsets,
                            sliver: _buildSeriesSliver(context, state),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          if (state.isLoading)
                            const SliverPadding(
                              padding: EdgeInsets.all(16.0),
                              sliver: SliverToBoxAdapter(
                                child: Center(child: LoadingWidget()),
                              ),
                            ),
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
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: _searchBar(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    final focusNode = FocusNode();
    return Container(
      padding: EdgeInsets.all(LLMTextInputTokens.padding.toDouble()),
      child: Container(
        decoration: BoxDecoration(
          color: LLMTextInputTokens.llmBgColor,
          borderRadius: BorderRadius.circular(
            focusNode.hasFocus
                ? LLMTextInputTokens.llmActiveCornerRadius.toDouble()
                : LLMTextInputTokens.llmCornerRadius.toDouble(),
          ),
        ),
        padding: EdgeInsets.all(LLMTextInputTokens.llmActivePadding.toDouble()),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                  controller: _searchController,
                  style: Theme.of(context).textTheme.small,
                  minLines: 1,
                  maxLines: 1,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Search artworks, exhibitions, artists, curators, or series',
                    hintStyle: Theme.of(context).textTheme.small,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: AppColor.auGrey,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching for artworks, exhibitions, artists, curators, or series',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
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
              _bloc.add(MeiliSearchQueryChanged(state.query));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildExhibitionsSliver(BuildContext context, MeiliSearchState state) {
    final exhibitions = state.exhibitions;
    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Exhibitions',
        builder: (context) {
          return ListExhibitionView(
            exhibitions: exhibitions,
            isScrollable: false,
            padding: EdgeInsets.zero,
            emptyWidget: const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildCuratorsSliver(BuildContext context, MeiliSearchState state) {
    final curators = state.curators;
    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Curators',
        builder: (context) {
          return ListAlumniView(
            listAlumni: curators,
            onAlumniSelected: (alumni) {
              unawaited(
                injector<NavigationService>()
                    .openFeralFileCuratorPage(alumni.slug ?? alumni.id),
              );
            },
            padding: EdgeInsets.zero,
            emptyWidget: const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildArtistsSliver(BuildContext context, MeiliSearchState state) {
    final artists = state.artists;
    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Artists',
        builder: (context) {
          return ListAlumniView(
            listAlumni: artists,
            onAlumniSelected: (alumni) {
              unawaited(
                injector<NavigationService>()
                    .openFeralFileArtistPage(alumni.slug ?? alumni.id),
              );
            },
            padding: EdgeInsets.zero,
            emptyWidget: const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _buildSeriesSliver(BuildContext context, MeiliSearchState state) {
    final series = state.series;
    return SliverToBoxAdapter(
      child: MeiliSearchResultSection<dynamic>(
        title: 'Series',
        builder: (context) {
          return SeriesView(
            series: series,
            isScrollable: false,
            padding: EdgeInsets.zero,
            userCollections: [],
          );
        },
      ),
    );
  }
}
