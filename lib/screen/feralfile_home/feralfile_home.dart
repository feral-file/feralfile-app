import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/explore_statistics_data.dart';
import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/screen/bloc/identity/identity_bloc.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_home/artwork_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/featured_work_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home_state.dart';
import 'package:autonomy_flutter/screen/feralfile_home/filter_bar.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_alumni_view.dart';
import 'package:autonomy_flutter/screen/feralfile_home/list_exhibition_view.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/exhibition_ext.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/keep_alive_widget.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FeralfileHomeTab {
  exhibitions,
  featured,
  artworks,
  artists,
  curators;

  List<SortBy> getSortBy({bool isSearching = false}) {
    switch (this) {
      case FeralfileHomeTab.artworks:
        return [
          if (isSearching) SortBy.relevance,
          SortBy.createdAt,
          SortBy.title,
        ];
      case FeralfileHomeTab.exhibitions:
        return [
          if (isSearching) SortBy.relevance,
          SortBy.openAt,
          SortBy.title,
        ];
      case FeralfileHomeTab.artists:
      case FeralfileHomeTab.curators:
        return [
          if (isSearching) SortBy.relevance,
          SortBy.firstExhibitionJoinedAt,
          SortBy.alias,
        ];
      default:
        return [
          if (isSearching) SortBy.relevance,
          SortBy.createdAt,
          SortBy.title,
        ];
    }
  }

  SortBy getDefaultSortBy({bool isSearching = false}) =>
      getSortBy(isSearching: isSearching).first;

  Map<FilterType, List<FilterValue>> getFilterBy() {
    switch (this) {
      case FeralfileHomeTab.artworks:
        return {
          FilterType.type: [
            FilterValue.edition,
            FilterValue.series,
            FilterValue.oneofone,
          ],
          FilterType.chain: [
            FilterValue.ethereum,
            FilterValue.tezos,
            // dont support Bitmark chain
          ],
          FilterType.medium: [
            FilterValue.image,
            FilterValue.video,
            FilterValue.software,
            FilterValue.pdf,
            FilterValue.audio,
            FilterValue.threeD,
            FilterValue.animatedGif,
            FilterValue.text,
          ],
        };
      case FeralfileHomeTab.exhibitions:
        return {
          FilterType.type: [
            FilterValue.solo,
            FilterValue.group,
          ],
        };
      default:
        return {};
    }
  }
}

class FeralfileHomePage extends StatefulWidget {
  const FeralfileHomePage({super.key});

  @override
  State<FeralfileHomePage> createState() => FeralfileHomePageState();
}

class FeralfileHomePageState extends State<FeralfileHomePage>
    with AutomaticKeepAliveClientMixin {
  late int _selectedIndex;
  late CanvasDeviceBloc _canvasDeviceBloc;
  final _featuredWorkKey = GlobalKey<FeaturedWorkViewState>();
  final _artworkViewKey = GlobalKey<ExploreSeriesViewState>();
  final _exhibitionViewKey = GlobalKey<ExploreExhibitionState>();
  final _artistViewKey = GlobalKey<ExploreArtistViewState>();
  final _curatorViewKey = GlobalKey<ExploreCuratorViewState>();
  final GlobalKey<_ItemExpandedWidgetState> _itemExpandedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
    context.read<FeralfileHomeBloc>().add(FeralFileHomeFetchDataEvent());
    _selectedIndex = FeralfileHomeTab.exhibitions.index;
  }

  void scrollToTop() {
    final tab = FeralfileHomeTab.values[_selectedIndex];
    switch (tab) {
      case FeralfileHomeTab.featured:
        _featuredWorkKey.currentState?.scrollToTop();
      case FeralfileHomeTab.artworks:
        _artworkViewKey.currentState?.scrollToTop();
      case FeralfileHomeTab.exhibitions:
        _exhibitionViewKey.currentState?.scrollToTop();
      case FeralfileHomeTab.artists:
        _artistViewKey.currentState?.scrollToTop();
      case FeralfileHomeTab.curators:
        _curatorViewKey.currentState?.scrollToTop();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: getDarkEmptyAppBar(Colors.transparent),
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: AppColor.primaryBlack,
      body: BlocBuilder<FeralfileHomeBloc, FeralfileHomeBlocState>(
        builder: (context, state) => _bodyWidget(state),
      ),
    );
  }

  void jumpToTab(FeralfileHomeTab tab) {
    _selectTab(tab);
    _itemExpandedKey.currentState?.selectItem(tab.index);
  }

  void _selectTab(FeralfileHomeTab tab) {
    setState(() {
      _selectedIndex = tab.index;
    });
  }

  List<Item> _getItemList(FeralfileHomeBlocState state) {
    final numberFormater = NumberFormat('#,###', 'en_US');
    return [
      Item(
        id: FeralfileHomeTab.exhibitions.index.toString(),
        title: 'exhibitions'.tr(),
        subtitle: state.exploreStatisticsData != null
            ? numberFormater
                .format(state.exploreStatisticsData!.totalExhibition)
            : '-',
        onSelected: () {
          _selectTab(FeralfileHomeTab.exhibitions);
        },
      ),
      Item(
        id: FeralfileHomeTab.featured.index.toString(),
        title: 'featured'.tr(),
        subtitle: state.featuredArtworks != null
            ? numberFormater.format(state.featuredArtworks!.length)
            : '-',
        onSelected: () {
          _selectTab(FeralfileHomeTab.featured);
        },
      ),
      Item(
        id: FeralfileHomeTab.artworks.index.toString(),
        title: '_artworks'.tr(),
        subtitle: state.exploreStatisticsData != null
            ? numberFormater.format(state.exploreStatisticsData!.totalArtwork)
            : '-',
        onSelected: () {
          _selectTab(FeralfileHomeTab.artworks);
        },
      ),
      Item(
        id: FeralfileHomeTab.artists.index.toString(),
        title: 'artists'.tr(),
        subtitle: state.exploreStatisticsData != null
            ? numberFormater.format(state.exploreStatisticsData!.totalArtist)
            : '-',
        onSelected: () {
          _selectTab(FeralfileHomeTab.artists);
        },
      ),
      Item(
        id: FeralfileHomeTab.curators.index.toString(),
        title: 'curators'.tr(),
        subtitle: state.exploreStatisticsData != null
            ? numberFormater.format(state.exploreStatisticsData!.totalCurator)
            : '-',
        onSelected: () {
          _selectTab(FeralfileHomeTab.curators);
        },
      ),
    ];
  }

  Widget _bodyWidget(FeralfileHomeBlocState state) {
    final tab = FeralfileHomeTab.values[_selectedIndex];
    switch (tab) {
      case FeralfileHomeTab.featured:
        return KeepAliveWidget(
          child: _featuredWidget(
            context,
            state.featuredArtworks ?? [],
          ),
        );
      case FeralfileHomeTab.artworks:
        return _artworksWidget(context);
      case FeralfileHomeTab.exhibitions:
        return _exhibitionsWidget(context);
      case FeralfileHomeTab.artists:
        return _artistsWidget(context);
      case FeralfileHomeTab.curators:
        return _curatorsWidget(context);
    }
  }

  Widget _getHeader(BuildContext context) {
    final icon = Icon(
      AuIcon.chevron_Sm,
      size: 18,
      color: Theme.of(context).colorScheme.secondary,
    );
    return Column(
      children: [
        BlocBuilder<FeralfileHomeBloc, FeralfileHomeBlocState>(
          builder: (context, state) => Padding(
            padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
            child: ItemExpandedWidget(
              key: _itemExpandedKey,
              items: _getItemList(state),
              selectedIndex: _selectedIndex,
              iconOnExpanded: RotatedBox(
                quarterTurns: 3,
                child: icon,
              ),
              iconOnUnExpanded: RotatedBox(
                quarterTurns: 1,
                child: icon,
              ),
              actions: [],
            ),
          ),
        ),
      ],
    );
  }

  Widget _featuredWidget(BuildContext context, List<Artwork> featuredArtworks) {
    final tokenIDs =
        featuredArtworks.map((e) => e.indexerTokenId).whereNotNull().toList();
    return MultiBlocProvider(
      providers: [
        BlocProvider<IdentityBloc>.value(
          value: injector.get<IdentityBloc>(),
        ),
      ],
      child: FeaturedWorkView(
        key: _featuredWorkKey,
        tokenIDs: tokenIDs,
        header: _getHeader(context),
      ),
    );
  }

  Widget _artworksWidget(BuildContext context) => ExploreSeriesView(
        key: _artworkViewKey,
        header: _getHeader(context),
      );

  Widget _exhibitionsWidget(BuildContext context) => ExploreExhibition(
        key: _exhibitionViewKey,
        header: _getHeader(context),
      );

  Widget _artistsWidget(BuildContext context) => ExploreArtistView(
        key: _artistViewKey,
        header: _getHeader(context),
      );

  Widget _curatorsWidget(BuildContext context) => ExploreCuratorView(
        key: _curatorViewKey,
        header: _getHeader(context),
      );

  @override
  bool get wantKeepAlive => true;
}

class Item {
  Item({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.onSelected,
  });

  String id;
  String title;
  String subtitle;
  Function onSelected;
}

class ItemExpandedWidget extends StatefulWidget {
  const ItemExpandedWidget({
    required this.items,
    required this.selectedIndex,
    super.key,
    this.iconOnExpanded,
    this.iconOnUnExpanded,
    this.actions = const [],
  });

  final Widget? iconOnExpanded;
  final Widget? iconOnUnExpanded;
  final List<Item> items;
  final int selectedIndex;

  // actions on unexpanded
  final List<Widget> actions;

  @override
  State<ItemExpandedWidget> createState() => _ItemExpandedWidgetState();
}

class _ItemExpandedWidgetState extends State<ItemExpandedWidget> {
  bool _isExpanded = false;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  void selectItem(int index) {
    setState(() {
      _selectedIndex = index;
      _isExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) => TapRegion(
        onTapOutside: (event) {
          setState(() {
            _isExpanded = false;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: ColoredBox(
                color: Colors.transparent,
                child: _isExpanded ? _expandedHeader() : _unexpandedHeader(),
              ),
            ),
            // Expanded items
            if (_isExpanded) ...[
              for (final item in widget.items.skip(1))
                _itemWidget(
                  context,
                  item,
                  withSubtitle: false,
                ),
            ],
          ],
        ),
      );

  Widget _expandedHeader() {
    final theme = Theme.of(context);
    final defaultIcon = Icon(
      AuIcon.chevron_Sm,
      size: 18,
      color: theme.colorScheme.secondary,
    );
    return Row(
      children: [
        _itemWidget(context, widget.items.first, withSubtitle: false),
        const Spacer(),
        Column(
          children: [
            widget.iconOnExpanded ?? defaultIcon,
          ],
        ),
      ],
    );
  }

  Widget _unexpandedHeader() {
    final theme = Theme.of(context);
    final defaultIcon = Icon(
      AuIcon.chevron_Sm,
      size: 18,
      color: theme.colorScheme.secondary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IgnorePointer(
              child: _itemWidget(context, _selectedItem(), withSubtitle: false),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                widget.iconOnUnExpanded ?? defaultIcon,
              ],
            ),
          ],
        ),
        const Spacer(),
        ...widget.actions,
      ],
    );
  }

  Item _selectedItem() => widget.items[_selectedIndex];

  Widget _itemWidget(
    BuildContext context,
    Item item, {
    bool withSubtitle = true,
  }) {
    final isSelected = item == _selectedItem();
    final theme = Theme.of(context);
    final defaultTitleStyle = theme.textTheme.ppMori700Black36
        .copyWith(color: AppColor.auGreyBackground);
    final selectedTitleStyle = theme.textTheme.ppMori700Black36.copyWith(
      color: AppColor.white,
    );
    final titleStyle = isSelected ? selectedTitleStyle : defaultTitleStyle;

    final defaultSubtitleStyle = theme.textTheme.ppMori400Black16
        .copyWith(color: AppColor.auGreyBackground);
    final selectedSubtitleStyle = theme.textTheme.ppMori400Black16.copyWith(
      color: AppColor.white,
    );
    final subtitleStyle =
        isSelected ? selectedSubtitleStyle : defaultSubtitleStyle;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = widget.items.indexOf(item);
          _isExpanded = false;
        });
        item.onSelected();
      },
      child: ColoredBox(
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: titleStyle,
            ),
            const SizedBox(width: 8),
            if (withSubtitle) Text(item.subtitle, style: subtitleStyle),
          ],
        ),
      ),
    );
  }
}
