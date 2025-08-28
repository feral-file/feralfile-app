import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_list_response.dart';
import 'package:autonomy_flutter/model/ff_series.dart';
import 'package:autonomy_flutter/nft_collection/models/user_collection.dart';
import 'package:autonomy_flutter/screen/feralfile_home/explore_search_bar.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/feralfile_home/filter_bar.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/series_ext.dart';
import 'package:autonomy_flutter/view/ff_series_tappable_thumbnail.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/user_collection_thumbnail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class ExploreSeriesView extends StatefulWidget {
  const ExploreSeriesView({
    this.pageSize = 20,
    super.key,
    this.header,
  });

  final int pageSize;
  final Widget? header;

  @override
  State<ExploreSeriesView> createState() => ExploreSeriesViewState();

  bool isEqual(Object other) =>
      other is ExploreSeriesView && other.pageSize == pageSize;
}

class ExploreSeriesViewState extends State<ExploreSeriesView> {
  List<FFSeries>? _series;
  List<UserCollection>? _userCollection;
  late Paging _paging;
  late ScrollController _scrollController;
  bool _isLoading = false;

  late String? _searchText;
  late Map<FilterType, FilterValue> _filters;
  late SortBy _sortBy;

  void scrollToTop() {
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels + 100 >
          _scrollController.position.maxScrollExtent) {
        unawaited(
          _loadMoreSeries(
            context,
            offset: _paging.offset + _paging.limit,
            pageSize: _paging.limit,
          ),
        );
      }
    });
    _paging = Paging(offset: 0, limit: widget.pageSize, total: 0);
    _searchText = null;
    _filters = {};
    _sortBy = FeralfileHomeTab.artworks.getDefaultSortBy();
    unawaited(
      _fetchSeries(context, offset: _paging.offset, pageSize: _paging.limit),
    );
  }

  @override
  void didUpdateWidget(covariant ExploreSeriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEqual(oldWidget)) {
      _series = null;
      _paging = Paging(offset: 0, limit: widget.pageSize, total: 0);
      unawaited(_fetchSeries(context));
    }
    scrollToTop();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _seriesView(
    BuildContext context,
    List<FFSeries>? series,
    List<UserCollection>? userCollection,
  ) =>
      SeriesView(
        series: series,
        userCollections: userCollection,
        scrollController: _scrollController,
        padding: const EdgeInsets.only(bottom: 100),
        exploreBar: _getExploreBar(context),
        header: widget.header,
      );

  Widget _getExploreBar(BuildContext context) => ExploreBar(
        key: const ValueKey(FeralfileHomeTab.artworks),
        onUpdate: (searchText, filters, sortBy) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            _searchText = searchText;
            _filters = filters;
            _sortBy = sortBy;
            unawaited(_fetchSeries(context));
          });
        },
      );

  @override
  Widget build(BuildContext context) =>
      _seriesView(context, _series, _userCollection);

  Future<List<FFSeries>> _fetchSeries(
    BuildContext context, {
    int offset = 0,
    int pageSize = 20,
  }) async {
    if (_isLoading) {
      return [];
    }
    _isLoading = true;
    log.info('[Artwork View] fetch series with keyword: $_searchText');
    final res = await injector<FeralFileService>().exploreArtworks(
      sortBy: _sortBy.queryParam,
      sortOrder: _sortBy.sortOrder.queryParam,
      keyword: _searchText ?? '',
      offset: offset,
      limit: pageSize,
      filters: _filters,
    );
    final series = res.result;
    final paging = res.paging!;
    setState(() {
      _series = series;

      _paging = paging;
    });
    _isLoading = false;
    return series;
  }

  Future<void> _loadMoreSeries(
    BuildContext context, {
    int offset = 0,
    int pageSize = 20,
  }) async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    final canLoadMore = _paging.offset < _paging.total;
    if (!canLoadMore) {
      _isLoading = false;
      return;
    }
    log.info('[Artwork View] load more series with keyword: $_searchText');
    final res = await injector<FeralFileService>().exploreArtworks(
      keyword: _searchText ?? '',
      offset: offset,
      limit: pageSize,
      sortBy: _sortBy.queryParam,
      sortOrder: _sortBy.sortOrder.queryParam,
      filters: _filters,
    );
    final series = res.result;
    final paging = res.paging!;
    setState(() {
      _series ??= [];
      _series!.addAll(series);
      _paging = paging;
    });
    _isLoading = false;
  }
}

class SeriesView extends StatefulWidget {
  const SeriesView({
    required this.series,
    required this.userCollections,
    this.scrollController,
    this.artist,
    super.key,
    this.isScrollable = true,
    this.padding = EdgeInsets.zero,
    this.limit,
    this.header,
    this.exploreBar,
  });

  final List<FFSeries>? series;
  final List<UserCollection>? userCollections;
  final AlumniAccount? artist;
  final ScrollController? scrollController;
  final bool isScrollable;
  final EdgeInsets padding;
  final int? limit;
  final Widget? header;
  final Widget? exploreBar;

  @override
  State<SeriesView> createState() => _SeriesViewState();
}

class _SeriesViewState extends State<SeriesView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  List<ArtistCollection>? getAllSeriesAndCollections() {
    final allSeries = widget.series;
    final allCollections = widget.userCollections;
    if (allSeries == null && allCollections == null) {
      return null;
    }

    return (allSeries == null || allCollections == null)
        ? allCollections ?? allSeries
        : mergeCollectionAndSeries(allCollections, allSeries);
  }

  Widget _loadingView(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 150),
        child: LoadingWidget(),
      );

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child:
          Text('no_series_found'.tr(), style: theme.textTheme.ppMori400White14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listSeriesAndCollections = getAllSeriesAndCollections();
    return CustomScrollView(
      controller: _scrollController,
      shrinkWrap: true,
      physics: widget.isScrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      slivers: [
        if (widget.header != null || widget.exploreBar != null) ...[
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top),
          ),
          // const SliverToBoxAdapter(
          //   child: NowDisplaying(),
          // ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
          SliverToBoxAdapter(
            child: widget.header ?? const SizedBox.shrink(),
          ),
          SliverToBoxAdapter(
            child: widget.exploreBar ?? const SizedBox.shrink(),
          ),
        ],
        if (listSeriesAndCollections == null) ...[
          SliverToBoxAdapter(
            child: _loadingView(context),
          ),
        ] else if (listSeriesAndCollections.isEmpty) ...[
          SliverToBoxAdapter(
            child: _emptyView(context),
          ),
        ] else ...[
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 188 / 307,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = listSeriesAndCollections[index];
                final border = Border(
                  top: const BorderSide(
                    color: AppColor.auGreyBackground,
                  ),
                  right: BorderSide(
                    color:
                        // if index is even, show border on the right
                        index.isEven
                            ? AppColor.auGreyBackground
                            : Colors.transparent,
                  ),
                  // if last row, add border on the bottom
                  bottom: index >= listSeriesAndCollections.length - 2
                      ? const BorderSide(
                          color: AppColor.auGreyBackground,
                        )
                      : BorderSide.none,
                );
                if (item is FFSeries) {
                  return _seriesItem(context, item, border);
                } else if (item is UserCollection) {
                  return _userCollectionItem(context, item, border);
                } else {
                  throw Exception('Unknown item type');
                }
              },
              childCount: widget.limit == null
                  ? listSeriesAndCollections.length
                  : min(widget.limit!, listSeriesAndCollections.length),
            ),
          ),
        ],
        SliverPadding(
          padding: widget.padding,
          sliver: const SliverToBoxAdapter(),
        ),
      ],
    );
  }

  Widget _seriesItem(BuildContext context, FFSeries series, Border border) =>
      Container(
        decoration: BoxDecoration(
          // border on the top and right
          border: border,
          color: Colors.transparent,
        ),
        padding: const EdgeInsets.all(8),
        child: FfSeriesInfoThumbnail(series: series),
      );

  Widget _userCollectionItem(
    BuildContext context,
    UserCollection collection,
    Border border,
  ) =>
      Container(
        decoration: BoxDecoration(
          // border on the top and right
          border: border,
          color: Colors.transparent,
        ),
        padding: const EdgeInsets.all(8),
        child: UserCollectionThumbnail(
          collection: collection,
          artist: widget.artist,
        ),
      );
}
