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
      body: Container(
        color: AppColor.white,
        padding: const EdgeInsets.all(16),
        child: Container(
          color: AppColor.auGreyBackground,
          child: NestedScrollView(
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              final height = innerBoxIsScrolled ? 75.0 : 123.0;
              final hamburgerButton = GestureDetector(
                onTap: () {
                  // Handle back button tap
                  // UIHelper.showCenterMenu(context,
                  //     options: _defaultOptions);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        right: 15, top: 16, left: 15, bottom: 16),
                    child: SvgPicture.asset(
                      'assets/images/icon_drawer.svg',
                      width: 22,
                      colorFilter: const ColorFilter.mode(
                        AppColor.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              );
              return [
                SliverAppBar(
                  pinned: false,
                  floating: true,
                  snap: true,
                  elevation: 0,
                  toolbarHeight: height,
                  expandedHeight: height,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: innerBoxIsScrolled
                          ? AppColor.red
                          : AppColor.feralFileHighlight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!innerBoxIsScrolled)
                            SizedBox(
                              height: 106,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  hamburgerButton,
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: HomeIndexHeader(
                                  selectedTab: _selectedTab,
                                  onTabChanged: (tab) {
                                    setState(() {
                                      _selectedTab = tab;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 16,
                              ),
                              if (innerBoxIsScrolled) hamburgerButton,
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: SingleChildScrollView(
              child: _buildContent(),
            ),
          ),
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
