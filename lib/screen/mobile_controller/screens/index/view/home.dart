import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/home_index_header.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Home Index Page - Main navigation with playlist sections
class HomeIndexPage extends StatefulWidget {
  const HomeIndexPage({super.key});

  @override
  State<HomeIndexPage> createState() => _HomeIndexPageState();
}

class _HomeIndexPageState extends State<HomeIndexPage> {
  late HomeIndexTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = HomeIndexTab.playlists;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Combined header: hamburgerButton + HomeIndexHeader
            // Full state: hamburgerButton (top-right) + HomeIndexHeader (bottom-left)
            // Collapse state: both on same row
            SliverPersistentHeader(
              pinned: false,
              floating: false,
              delegate: _CombinedHeaderDelegate(
                selectedTab: _selectedTab,
                onTabChanged: (tab) {
                  setState(() {
                    _selectedTab = tab;
                  });
                },
                isBodyScrolling: innerBoxIsScrolled,
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case HomeIndexTab.playlists:
        return const PlaylistsPage();
      case HomeIndexTab.channels:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Channels',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      case HomeIndexTab.works:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Works',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
    }
  }
}

/// Combined header delegate: hamburgerButton on top, HomeIndexHeader below
/// HomeIndexHeader scrolls out while hamburgerButton stays visible
class _CombinedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CombinedHeaderDelegate({
    required this.selectedTab,
    required this.onTabChanged,
    required this.isBodyScrolling,
  });

  final HomeIndexTab selectedTab;
  final void Function(HomeIndexTab) onTabChanged;
  final bool isBodyScrolling;

  static const double _minExtent = 75.0;
  static const double _maxExtent = 123.0;
  static const double _headerHeight = 17.0;
  static const double _hamburgerHeight =
      _maxExtent - _minExtent; // 48 - scroll range

  @override
  double get minExtent => _minExtent;

  @override
  double get maxExtent => _maxExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Calculate how much to scroll the HomeIndexHeader
    // As we scroll, HomeIndexHeader moves up
    final headerOffset = shrinkOffset.clamp(0.0, _hamburgerHeight);

    return Container(
      color: AppColor.red,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hamburger button - stays at top
          SizedBox(
            height: 106,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    // Handle hamburger menu tap
                  },
                  child: Container(
                    color: Colors.amber,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 15,
                        top: 12,
                        left: 15,
                        bottom: 12,
                      ),
                      child: SvgPicture.asset(
                        'assets/images/icon_drawer.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColor.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // HomeIndexHeader - scrolls up
          Transform.translate(
            offset: Offset(0, -headerOffset),
            child: Container(
              height: _headerHeight,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: HomeIndexHeader(
                  selectedTab: selectedTab,
                  onTabChanged: onTabChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_CombinedHeaderDelegate oldDelegate) =>
      oldDelegate.selectedTab != selectedTab ||
      oldDelegate.isBodyScrolling != isBodyScrolling;
}
