import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/onboarding/add_address_input_page.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/channels_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/works/works_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/home_index_header.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/screen/search/search_page.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/no_pairing_device_dialog.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/foundation.dart';
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
  late final PlaylistsPage _playlistsPage;
  late final ChannelsPage _channelsPage;
  late final WorksPage _worksPage;

  @override
  void initState() {
    super.initState();
    _selectedTab = HomeIndexTab.playlists;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollChange);
    _playlistsPage = PlaylistsPage(key: _playlistsPageKey);
    _channelsPage = ChannelsPage(key: _channelsPageKey);
    _worksPage = WorksPage(key: _worksPageKey);
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
      // scan option for debug only
      if (kDebugMode)
        OptionItem(
          title: 'Scan',
          icon: const Icon(
            AuIcon.scan,
          ),
          onTap: () {
            injector<NavigationService>().navigateTo(AppRouter.scanQRPage,
                arguments: ScanQRPagePayload(
                  scannerItem: ScannerItem.GLOBAL,
                ));
            isNowDisplayingBarExpanded.value = false;
          },
        ),
      // FF1 Setting
      OptionItem(
        title: 'FF1 Art Computer',
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
        icon: SvgPicture.asset(
          'assets/images/account_setting.svg',
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
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
              // injector<CustomerSupportService>().numberOfIssuesInfo,
              ValueNotifier<List<int>?>(null),
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

  Widget _addAddressButton() {
    return CustomPrimaryButton(
      onTap: () async {
        final address = await injector<NavigationService>().navigateTo(
          AppRouter.onboardingAddAddressInputPage,
          arguments: OnboardingAddAddressInputPagePayload(
            isFromOnboarding: false,
          ),
        );

        if (address != null) {
          injector<NavigationService>().goBack();
        }
      },
      borderColor: AppColor.feralFileLightBlue,
      color: Colors.transparent,
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/Add_blue.svg',
            colorFilter: const ColorFilter.mode(
              PrimitivesTokens.colorsLightBlue,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Add Address',
            style: Theme.of(context).textTheme.body.copyWith(
                  color: PrimitivesTokens.colorsLightBlue,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: NestedScrollView(
        controller: _scrollController,
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          const height = 43.5;
          final hamburgerButton = GestureDetector(
            onTap: () {
              // Handle back button tap
              UIHelper.showCenterMenu(
                context,
                options: _defaultOptions,
                bottomWidget: _addAddressButton(),
              );
            },
            child: Container(
              color: Colors.transparent,
              width: LayoutConstants.minTouchTarget,
              height: LayoutConstants.minTouchTarget,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/Drawer.svg',
                  width: LayoutConstants.iconSizeMedium,
                  height: LayoutConstants.iconSizeMedium,
                  colorFilter:
                      const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
                ),
              ),
            ),
          );
          final searchButton = GestureDetector(
            onTap: () {
              injector<NavigationService>().navigateTo(AppRouter.searchPage,
                  arguments: SearchPagePayload(autoFocus: true));
              isNowDisplayingBarExpanded.value = false;
            },
            child: Container(
              color: Colors.transparent,
              width: LayoutConstants.minTouchTarget,
              height: LayoutConstants.minTouchTarget,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/search.svg',
                  width: LayoutConstants.iconSizeMedium,
                  height: LayoutConstants.iconSizeMedium,
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
                            width: LayoutConstants.space3,
                          ),
                          searchButton,
                          hamburgerButton,
                          SizedBox(width: LayoutConstants.space3),
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
          child: _playlistsPage,
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexTab.channels,
          child: _channelsPage,
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexTab.works,
          child: _worksPage,
        ),
      ],
    );
  }
}
