import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/ff_alumni.dart';
import 'package:autonomy_flutter/model/ff_list_response.dart';
import 'package:autonomy_flutter/screen/feralfile_home/explore_search_bar.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/feralfile_home/filter_bar.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/feral_file_explore_helper.dart';
import 'package:autonomy_flutter/util/feralfile_alumni_ext.dart';
import 'package:autonomy_flutter/view/alumni_widget.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:flutter/material.dart';

class ExploreArtistView extends StatefulWidget {
  const ExploreArtistView({super.key, this.header});

  final Widget? header;

  @override
  State<ExploreArtistView> createState() => ExploreArtistViewState();
}

class ExploreArtistViewState extends State<ExploreArtistView> {
  List<AlumniAccount>? _artists;
  late Paging _paging;
  late ScrollController _scrollController;
  bool _isLoading = false;

  late String? _searchText;
  late SortBy _sortBy;

  @override
  void initState() {
    super.initState();
    _paging = Paging(offset: 0, limit: 18, total: 0);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels + 100 >
          _scrollController.position.maxScrollExtent) {
        unawaited(_loadMore());
      }
    });
    _searchText = null;
    _sortBy = FeralfileHomeTab.artists.getDefaultSortBy();
    unawaited(_fetchArtists(context));
  }

  @override
  void didUpdateWidget(covariant ExploreArtistView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text('No artists found', style: theme.textTheme.ppMori400White14),
    );
  }

  Widget _getExploreBar(BuildContext context) => ExploreBar(
        key: const ValueKey(FeralfileHomeTab.artists),
        onUpdate: (searchText, filters, sortBy) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            _searchText = searchText;
            _sortBy = sortBy;
            await _fetchArtists(context);
          });
        },
        tab: FeralfileHomeTab.artists,
      );

  Widget _artistView(BuildContext context, List<AlumniAccount>? artists) =>
      ListAlumniView(
        listAlumni: artists,
        onAlumniSelected: (alumni) {
          unawaited(
            injector<NavigationService>()
                .openFeralFileArtistPage(alumni.slug ?? alumni.id),
          );
        },
        scrollController: _scrollController,
        padding: const EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 100,
        ),
        header: widget.header,
        exploreBar: _getExploreBar(context),
        emptyWidget: _emptyView(context),
      );

  @override
  Widget build(BuildContext context) => _artistView(context, _artists);

  Future<List<AlumniAccount>> _fetchArtists(BuildContext context) async {
    if (_isLoading) {
      return [];
    }
    _isLoading = true;

    final resp = await injector<FeralFileService>().getListAlumni(
      keywork: _searchText ?? '',
      isArtist: true,
      orderBy: _sortBy.queryParam,
      sortOrder: _sortBy.sortOrder.queryParam,
    );
    final artists = resp.result;
    final paging = resp.paging!;
    setState(() {
      _artists = artists;
      _paging = paging;
    });
    _isLoading = false;
    return artists;
  }

  Future<void> _loadMore() async {
    if (_isLoading) {
      return;
    }
    final canLoadMore = _paging.offset < _paging.total;
    if (!canLoadMore) {
      return;
    }
    _isLoading = true;
    final resp = await injector<FeralFileService>().getListAlumni(
      keywork: _searchText ?? '',
      isArtist: true,
      offset: _paging.offset + _paging.limit,
      limit: _paging.limit,
      orderBy: _sortBy.queryParam,
    );

    final artists = resp.result;
    final paging = resp.paging!;
    setState(() {
      _artists!.addAll(artists);
      _paging = paging;
    });
    _isLoading = false;
  }
}

class ExploreCuratorView extends StatefulWidget {
  const ExploreCuratorView({super.key, this.header});

  final Widget? header;

  @override
  State<ExploreCuratorView> createState() => ExploreCuratorViewState();
}

class ExploreCuratorViewState extends State<ExploreCuratorView> {
  List<AlumniAccount>? _curators;
  late ScrollController _scrollController;
  late Paging _paging;
  bool _isLoading = false;

  late String? _searchText;
  late SortBy _sortBy;

  @override
  void initState() {
    super.initState();
    _paging = Paging(offset: 0, limit: 18, total: 0);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels + 100 >
          _scrollController.position.maxScrollExtent) {
        unawaited(_loadMore());
      }
    });
    _searchText = null;
    _sortBy = FeralfileHomeTab.curators.getDefaultSortBy();
    unawaited(_fetchCurators(context));
  }

  @override
  void didUpdateWidget(covariant ExploreCuratorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_fetchCurators(context));
    scrollToTop();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    unawaited(
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _emptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text('no_curator_found', style: theme.textTheme.ppMori400White14),
    );
  }

  Widget _getExploreBar(BuildContext context) => ExploreBar(
        key: const ValueKey(FeralfileHomeTab.artists),
        onUpdate: (searchText, filters, sortBy) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            _searchText = searchText;
            _sortBy = sortBy;
            await _fetchCurators(context);
          });
        },
        tab: FeralfileHomeTab.artists,
      );

  Widget _curatorView(BuildContext context, List<AlumniAccount>? curators) =>
      ListAlumniView(
        listAlumni: curators,
        onAlumniSelected: (alumni) {
          unawaited(
            injector<NavigationService>()
                .openFeralFileCuratorPage(alumni.slug ?? alumni.id),
          );
        },
        scrollController: _scrollController,
        padding: const EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 100,
        ),
        header: widget.header,
        exploreBar: _getExploreBar(context),
        emptyWidget: _emptyView(context),
      );

  @override
  Widget build(BuildContext context) => _curatorView(context, _curators);

  Future<List<AlumniAccount>> _fetchCurators(BuildContext context) async {
    if (_isLoading) {
      return [];
    }
    _isLoading = true;
    final resp = await injector<FeralFileService>().getListAlumni(
      keywork: _searchText ?? '',
      isCurator: true,
      orderBy: _sortBy.queryParam,
      sortOrder: _sortBy.sortOrder.queryParam,
    );
    final ignoreCuratorAddresses =
        FeralFileExploreHelper.ignoreCuratorAddresses;
    final curators = resp.result;
    final paging = resp.paging!;
    setState(() {
      _curators = curators
          .where(
            (curator) =>
                !curator.addressesList.any(ignoreCuratorAddresses.contains),
          )
          .toList();
      _paging = paging;
    });
    _isLoading = false;
    return curators;
  }

  Future<void> _loadMore() async {
    if (_isLoading) {
      return;
    }
    final canLoadMore = _paging.offset < _paging.total;
    if (!canLoadMore) {
      return;
    }
    _isLoading = true;
    final resp = await injector<FeralFileService>().getListAlumni(
      keywork: _searchText ?? '',
      isCurator: true,
      offset: _paging.offset + _paging.limit,
      limit: _paging.limit,
      orderBy: _sortBy.queryParam,
      sortOrder: _sortBy.sortOrder.queryParam,
    );

    final ignoreCuratorAddresses =
        FeralFileExploreHelper.ignoreCuratorAddresses;

    final curators = resp.result;
    final paging = resp.paging!;
    setState(() {
      _curators!.addAll(
        curators
            .where(
              (curator) =>
                  !curator.addressesList.any(ignoreCuratorAddresses.contains),
            )
            .toList(),
      );
      _paging = paging;
    });
    _isLoading = false;
  }
}

class ListAlumniView extends StatefulWidget {
  const ListAlumniView({
    required this.listAlumni,
    required this.onAlumniSelected,
    this.scrollController,
    this.padding = EdgeInsets.zero,
    super.key,
    this.header,
    this.exploreBar,
    this.emptyWidget,
  });

  final List<AlumniAccount>? listAlumni;
  final Function(AlumniAccount) onAlumniSelected;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final Widget? header;
  final Widget? exploreBar;
  final Widget? emptyWidget;

  @override
  State<ListAlumniView> createState() => _ListAlumniViewState();
}

class _ListAlumniViewState extends State<ListAlumniView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  Widget _loadingView(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 150),
        child: LoadingWidget(),
      );

  @override
  Widget build(BuildContext context) => CustomScrollView(
        controller: _scrollController,
        shrinkWrap: true,
        slivers: [
          if (widget.exploreBar != null || widget.header != null) ...[
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.of(context).padding.top),
            ),
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
          if (widget.listAlumni == null) ...[
            SliverToBoxAdapter(
              child: _loadingView(context),
            ),
          ] else if (widget.listAlumni!.isEmpty) ...[
            SliverToBoxAdapter(
              child: widget.emptyWidget ?? const SizedBox.shrink(),
            ),
          ] else ...[
            SliverPadding(
              padding: widget.padding,
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 102.0 / 152,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 30,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final alumni = widget.listAlumni![index];
                    return GestureDetector(
                      onTap: () {
                        widget.onAlumniSelected(alumni);
                      },
                      child: ColoredBox(
                        color: Colors.transparent,
                        child: _artistItem(context, alumni),
                      ),
                    );
                  },
                  childCount: widget.listAlumni!.length,
                ),
              ),
            ),
          ],
        ],
      );

  Widget _artistItem(BuildContext context, AlumniAccount alumni) {
    return AlumniCard(
      alumni: alumni,
    );
  }
}

class AlumniCard extends StatelessWidget {
  const AlumniCard({
    super.key,
    required this.alumni,
  });

  final AlumniAccount alumni;

  Widget _artistAvatar(BuildContext context, AlumniAccount alumni) {
    final avatarUrl = alumni.avatarUrl;
    return AlumniAvatar(url: avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(aspectRatio: 1, child: _artistAvatar(context, alumni)),
        const SizedBox(height: 14),
        Expanded(
          child: Text(
            alumni.displayAlias,
            style: theme.textTheme.ppMori400White12,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
