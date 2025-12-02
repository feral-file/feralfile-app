import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/channels_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/works/works_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/home_index_header.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/no_pairing_device_dialog.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Home Index Page - Main navigation with playlist sections
///

final GlobalKey<PlaylistsPageState> _playlistsPageKey =
    GlobalKey<PlaylistsPageState>();
final GlobalKey<ChannelsPageState> _channelsPageKey =
    GlobalKey<ChannelsPageState>();
final GlobalKey<WorksPageState> _worksPageKey = GlobalKey<WorksPageState>();

class HomeIndexPage extends StatefulWidget {
  const HomeIndexPage({super.key});

  @override
  State<HomeIndexPage> createState() => _HomeIndexPageState();
}

class _HomeIndexPageState extends State<HomeIndexPage> {
  late HomeIndexTab _selectedTab;
  final TransformationController _transformationController =
      TransformationController();
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedTab = HomeIndexTab.playlists;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollChange);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChange);
    _scrollController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onScrollChange() {
    // Delegate scroll events to current page's load more logic
    if (_selectedTab == HomeIndexTab.works) {
      // WorksPage will handle load more through scroll position
    }
  }

  Future<void> showNoParingDialog() async {
    const screenKey = 'No pairing';
    if (UIHelper.currentDialogTitle == screenKey) {
      return;
    }

    UIHelper.currentDialogTitle = screenKey;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (context) => NoPairingDeviceDialog(),
    );

    UIHelper.currentDialogTitle = '';
  }

  List<OptionItem> get _defaultOptions {
    return [
      // FF1 Setting
      OptionItem(
        title: 'FF1',
        icon: SvgPicture.asset(
          'assets/images/portal_setting.svg',
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          if (BluetoothDeviceManager().castingBluetoothDevice == null) {
            showNoParingDialog();
            return;
          }

          injector<NavigationService>().navigateTo(
            AppRouter.bluetoothConnectedDeviceConfig,
            arguments: BluetoothConnectedDeviceConfigPayload(),
          );
          isNowDisplayingBarExpanded.value = false;
        },
      ),

      // Personal Preferences & Data, Security Management
      OptionItem(
        title: 'Account',
        icon: const Icon(
          AuIcon.settings,
        ),
        onTap: () {
          injector<NavigationService>().navigateTo(AppRouter.settingsPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),

      // Support & Feedback
      OptionItem(
        title: 'Support & Feedback',
        icon: ValueListenableBuilder<List<int>?>(
          valueListenable:
              injector<CustomerSupportService>().numberOfIssuesInfo,
          builder: (
            BuildContext context,
            List<int>? numberOfIssuesInfo,
            Widget? child,
          ) =>
              iconWithRedDot(
            icon: const Icon(
              AuIcon.help,
            ),
            padding: const EdgeInsets.only(right: 2, top: 2),
            withReddot: numberOfIssuesInfo != null && numberOfIssuesInfo[1] > 0,
          ),
        ),
        onTap: () {
          injector<NavigationService>()
              .navigateTo(AppRouter.supportCustomerPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),

      // Release Notes
      OptionItem(
        title: 'Release Notes',
        icon: SvgPicture.asset(
          'assets/images/release_notes.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          injector<NavigationService>().navigateTo(AppRouter.releaseNotesPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: NestedScrollView(
        controller: _scrollController,
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final height = 43.5;
          final hamburgerButton = GestureDetector(
            onTap: () {
              // Handle back button tap
              UIHelper.showCenterMenu(
                context,
                options: _defaultOptions,
              );
            },
            child: Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 15,
                  top: 14,
                  left: 15,
                  bottom: 14,
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
                  color: AppColor.auGreyBackground,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // if (!innerBoxIsScrolled)
                      //   SizedBox(
                      //     height: 106,
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.end,
                      //       children: [
                      //         hamburgerButton,
                      //       ],
                      //     ),
                      //   ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: HomeIndexHeader(
                                selectedTab: _selectedTab,
                                onTabChanged: (tab) {
                                  setState(() {
                                    _selectedTab = tab;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 16,
                          ),
                          hamburgerButton,
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
          child: Column(
            children: [
              const SizedBox(height: 37),
              _buildContent(),
              const BottomSpacing()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Use Stack with Offstage instead of IndexedStack
    // Offstage keeps widgets alive (not disposed) while hiding them
    // This allows each page to have independent constraints
    // Combined with AutomaticKeepAliveClientMixin in each page, state is preserved
    // Each page can determine its own height (limited or unlimited) independently
    return Stack(
      children: [
        Offstage(
          offstage: _selectedTab != HomeIndexTab.playlists,
          child: PlaylistsPage(key: _playlistsPageKey),
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexTab.channels,
          child: ChannelsPage(key: _channelsPageKey),
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexTab.works,
          child: WorksPage(key: _worksPageKey),
        ),
      ],
    );
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

  List<OptionItem> get _defaultOptions {
    return [
      // FF1 Setting
      OptionItem(
        title: 'FF1',
        icon: SvgPicture.asset(
          'assets/images/portal_setting.svg',
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          if (BluetoothDeviceManager().castingBluetoothDevice != null) {
            return;
          }

          injector<NavigationService>().navigateTo(
            AppRouter.bluetoothConnectedDeviceConfig,
            arguments: BluetoothConnectedDeviceConfigPayload(),
          );
          isNowDisplayingBarExpanded.value = false;
        },
      ),

      // Personal Preferences & Data, Security Management
      OptionItem(
        title: 'Account',
        icon: const Icon(
          AuIcon.settings,
        ),
        onTap: () {
          injector<NavigationService>().navigateTo(AppRouter.settingsPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),

      // Support & Feedback
      OptionItem(
        title: 'Support & Feedback',
        icon: ValueListenableBuilder<List<int>?>(
          valueListenable:
              injector<CustomerSupportService>().numberOfIssuesInfo,
          builder: (
            BuildContext context,
            List<int>? numberOfIssuesInfo,
            Widget? child,
          ) =>
              iconWithRedDot(
            icon: const Icon(
              AuIcon.help,
            ),
            padding: const EdgeInsets.only(right: 2, top: 2),
            withReddot: numberOfIssuesInfo != null && numberOfIssuesInfo[1] > 0,
          ),
        ),
        onTap: () {
          injector<NavigationService>()
              .navigateTo(AppRouter.supportCustomerPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),

      // Release Notes
      OptionItem(
        title: 'Release Notes',
        icon: SvgPicture.asset(
          'assets/images/release_notes.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          injector<NavigationService>().navigateTo(AppRouter.releaseNotesPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),
    ];
  }

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

    return Column(
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

                    UIHelper.showCenterMenu(context, options: _defaultOptions);
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
          child: SizedBox(
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
    );
  }

  @override
  bool shouldRebuild(_CombinedHeaderDelegate oldDelegate) =>
      oldDelegate.selectedTab != selectedTab ||
      oldDelegate.isBodyScrolling != isBodyScrolling;
}
