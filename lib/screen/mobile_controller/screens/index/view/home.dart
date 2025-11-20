import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/home_index_header.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
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
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _selectedTab = HomeIndexTab.playlists;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 16.0,
        child: Stack(
          children: [
            NestedScrollView(
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Add padding before header
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 48),
                    sliver: SliverPersistentHeader(
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
                  ),
                ];
              },
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    _buildContent(),
                    const BottomSpacing()
                  ],
                ),
              ),
            ),
            // Figma design overlay for comparison - zooms with content
            // Opacity(
            //   opacity: 0.3,
            //   child: Container(
            //     width: double.infinity,
            //     height: double.infinity,
            //     child: Image.asset(
            //       'assets/images/No Scroll.png',
            //       fit: BoxFit.fitWidth,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case HomeIndexTab.playlists:
        return Container(child: const PlaylistsPage());
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

    // Calculate available height for hamburger button
    // Shrinks proportionally as header collapses
    final availableHeight = maxExtent - shrinkOffset;
    final hamburgerHeight =
        (availableHeight - _headerHeight).clamp(44.0, 106.0);

    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hamburger button - responsive height as header collapses
          SizedBox(
            height: hamburgerHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 15.5),
                  child: GestureDetector(
                    onTap: () {
                      // Handle hamburger menu tap
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 15,
                        top: 12,
                        left: 15,
                        bottom: 12,
                      ),
                      child: SvgPicture.asset(
                        'assets/images/Drawer.svg',
                        width: 22,
                        height: 14,
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
