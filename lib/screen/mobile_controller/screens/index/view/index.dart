import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/channels_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/collection_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/playlists_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/works/works_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/header.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

final directoryPageGlobalKey = GlobalKey<ListDirectoryPageState>();

class ListDirectoryPage extends StatefulWidget {
  const ListDirectoryPage({super.key});

  @override
  State<ListDirectoryPage> createState() => ListDirectoryPageState();
}

class ListDirectoryPageState extends State<ListDirectoryPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, RouteAware {
  late PageController _pageController;
  late ScrollController _scrollController;
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    if (_selectedPageIndex == 3) {
      _reindexAllAddresses();
    }
  }

  void openMyCollection() {
    _onPageChanged(3);
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedPageIndex = index;
    });
    _pageController.jumpToPage(index);
    if (index == 3) {
      _reindexAllAddresses();
    }
  }

  Future<void> _reindexAllAddresses() async {
    final allAddresses = injector<AddressService>().getAllAddresses();
    await injector<NftTokensService>().reindexAddresses(allAddresses);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    Widget buildPage(int index, ScrollController scrollController, Key key) {
      switch (index) {
        case 0:
          return PlaylistsPage(scrollController: scrollController, key: key);
        case 1:
          return ChannelsPage(scrollController: scrollController, key: key);
        case 2:
          return WorksPage(scrollController: scrollController, key: key);
        case 3:
          return CollectionPage(scrollController: scrollController, key: key);
        default:
          return const SizedBox.shrink();
      }
    }

    final pageBuilders = [
      (ScrollController scrollController, Key key) =>
          PlaylistsPage(scrollController: scrollController, key: key),
      (ScrollController scrollController, Key key) =>
          ChannelsPage(scrollController: scrollController, key: key),
      (ScrollController scrollController, Key key) =>
          WorksPage(scrollController: scrollController, key: key),
      (ScrollController scrollController, Key key) =>
          CollectionPage(scrollController: scrollController, key: key),
    ];

    // return NestedPageViewExample();

    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            expandedHeight: 154.0 + MediaQuery.of(context).padding.top,
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).padding.top,
                  ),
                  SizedBox(
                    height: 154,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // Handle back button tap
                            UIHelper.showCenterMenu(context,
                                options: _defaultOptions);
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                HeaderWidget(
                  selectedIndex: _selectedPageIndex,
                  onPageChanged: _onPageChanged,
                ),
                const SizedBox(height: UIConstants.detailPageHeaderPadding),
              ],
            ),
          ),
        ];
      },
      body: PageView.builder(
        controller: _pageController,
        itemCount: pageBuilders.length,
        itemBuilder: (context, index) {
          return Builder(
            builder: (context) {
              final innerController = PrimaryScrollController.of(context);
              return pageBuilders[index](
                  innerController, PageStorageKey('page_$index'));
            },
          );
        },
      ),
    );
  }

  List<OptionItem> get _defaultOptions {
    return [
      // scan
      OptionItem(
        title: 'scan'.tr(),
        icon: const Icon(
          AuIcon.scan,
        ),
        onTap: () {
          injector<NavigationService>().navigateTo(
            AppRouter.scanQRPage,
            arguments: const ScanQRPagePayload(scannerItem: ScannerItem.GLOBAL),
          );
          isNowDisplayingBarExpanded.value = false;
        },
      ),
      if (injector<AuthService>().isBetaTester() &&
          BluetoothDeviceManager().castingBluetoothDevice != null)
        // FF-X1 Setting
        OptionItem(
          title: 'FF1 Settings',
          icon: SvgPicture.asset(
            'assets/images/portal_setting.svg',
            colorFilter:
                const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
          ),
          onTap: () {
            injector<NavigationService>().navigateTo(
              AppRouter.bluetoothConnectedDeviceConfig,
              arguments: BluetoothConnectedDeviceConfigPayload(),
            );
            isNowDisplayingBarExpanded.value = false;
          },
        ),
      // OptionItem(
      //   title: 'Custom Feed Server',
      //   icon: const Icon(
      //     AuIcon.settings,
      //   ),
      //   onTap: () {
      //     injector<NavigationService>()
      //         .navigateTo(AppRouter.customFeedServersPage);
      //     isNowDisplayingBarExpanded.value = false;
      //   },
      // ),
      OptionItem(
        title: 'App Settings',
        icon: const Icon(
          AuIcon.settings,
        ),
        onTap: () {
          injector<NavigationService>().navigateTo(AppRouter.settingsPage);
          isNowDisplayingBarExpanded.value = false;
        },
      ),
      OptionItem(
        title: 'wallet'.tr(),
        icon: const Icon(
          AuIcon.wallet,
        ),
        onTap: () {
          Navigator.of(context).pushNamed(AppRouter.walletPage);
        },
      ),

      // help
      OptionItem(
        title: 'help'.tr(),
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
    ];
  }

  @override
  bool get wantKeepAlive => true;
}

class NestedPageViewExample extends StatefulWidget {
  @override
  _NestedPageViewExampleState createState() => _NestedPageViewExampleState();
}

class _NestedPageViewExampleState extends State<NestedPageViewExample> {
  late PageController _pageController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('Nested Scroll + PageView'),
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Image.network(
                  'https://picsum.photos/800/400',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ];
        },
        body: PageView(
          controller: _pageController,
          children: [
            // Each page gets its own Builder
            Builder(
              builder: (context) => _buildCustomScrollView(
                  context, "Page 1", Colors.blue.shade50),
            ),
            Builder(
              builder: (context) => _buildCustomScrollView(
                  context, "Page 2", Colors.green.shade50),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomScrollView(
      BuildContext context, String title, Color color) {
    // ✅ Now this context is correct (inside NestedScrollView body)
    final innerController = PrimaryScrollController.of(context);

    return CustomScrollView(
      controller: innerController,
      key: PageStorageKey(title),
      slivers: List.generate(
        100,
        (index) => SliverToBoxAdapter(
          child: Container(
            height: 100,
            color: color,
            alignment: Alignment.center,
            child: Text(
              '$title - Item $index',
              style: const TextStyle(fontSize: 24, color: Colors.amber),
            ),
          ),
        ),
      ),
    );
  }
}
