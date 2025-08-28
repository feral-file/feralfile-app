//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_bloc.dart';
import 'package:autonomy_flutter/screen/dailies_work/dailies_work_page.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home_bloc.dart';
import 'package:autonomy_flutter/screen/home/list_playlist_bloc.dart';
import 'package:autonomy_flutter/screen/home/organize_home_page.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/client_token_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/homepage_navigation_bar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeNavigationPagePayload {
  const HomeNavigationPagePayload({
    bool? fromOnboarding,
    HomeNavigatorTab? startedTab,
  })  : fromOnboarding = fromOnboarding ?? false,
        startedTab = startedTab ?? HomeNavigatorTab.daily;

  final bool fromOnboarding;
  final HomeNavigatorTab startedTab;
}

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({
    super.key,
    this.payload = const HomeNavigationPagePayload(),
  });

  final HomeNavigationPagePayload payload;

  @override
  State<HomeNavigationPage> createState() => HomeNavigationPageState();
}

class HomeNavigationPageState extends State<HomeNavigationPage>
    with
        RouteAware,
        WidgetsBindingObserver,
        AfterLayoutMixin<HomeNavigationPage> {
  late int _selectedIndex;
  PageController? _pageController;
  late List<Widget> _pages;
  final GlobalKey<OrganizeHomePageState> _organizeHomeKey = GlobalKey();
  final _configurationService = injector<ConfigurationService>();
  Timer? _timer;
  final _clientTokenService = injector<ClientTokenService>();
  late HomeNavigatorTab _initialTab;
  final nftBloc = injector<ClientTokenService>().nftBloc;
  final _subscriptionBloc = injector<SubscriptionBloc>();

  StreamSubscription<FGBGType>? _fgbgSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  Future<void> openExhibition(String exhibitionId) async {
    await onItemTapped(HomeNavigatorTab.explore.index);
  }

  void _notifyMoveOutDaily() {
    dailyWorkKey.currentState?.didPushed();
  }

  Future<void> onItemTapped(int index) async {
    if (index != HomeNavigatorTab.daily.index) {
      _notifyMoveOutDaily();
    }
    if (index < _pages.length) {
      // handle scroll to top when tap on the same tab
      if (_selectedIndex == index) {
        if (index == HomeNavigatorTab.explore.index) {
          feralFileHomeKey.currentState?.scrollToTop();
        } else if (index == HomeNavigatorTab.daily.index) {
          dailyWorkKey.currentState?.scrollToTop();
        } else if (index == HomeNavigatorTab.collection.index) {
          _organizeHomeKey.currentState?.scrollToTop();
        }
      }
      // when user change tap
      else {
        // if tap on daily, resume daily work,
        // otherwise pause daily work
        if (index == HomeNavigatorTab.daily.index) {
          dailyWorkKey.currentState?.resumeDailyWork();
          dailyWorkKey.currentState?.trackInterest();
        } else {
          dailyWorkKey.currentState?.pauseDailyWork();
        }
      }
      setState(() {
        _selectedIndex = index;
      });
      _pageController?.jumpToPage(_selectedIndex);
    }
    // handle hamburger menu
    else {
      final currentIndex = _selectedIndex;
      setState(() {
        _selectedIndex = index;
      });

      await UIHelper.showCenterMenu(
        context,
        routeSettings: const RouteSettings(name: UIHelper.homeMenu),
        options: [
          OptionItem(
            title: 'scan'.tr(),
            icon: const Icon(
              AuIcon.scan,
            ),
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRouter.scanQRPage,
                arguments:
                    const ScanQRPagePayload(scannerItem: ScannerItem.GLOBAL),
              );
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
          OptionItem(
            title: 'settings'.tr(),
            icon: const Icon(
              AuIcon.settings,
            ),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.settingsPage);
            },
          ),
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
                withReddot:
                    numberOfIssuesInfo != null && numberOfIssuesInfo[1] > 0,
              ),
            ),
            onTap: () {
              Navigator.of(context).pushNamed(AppRouter.supportCustomerPage);
            },
          ),
        ],
      );
      if (mounted) {
        setState(() {
          _selectedIndex = currentIndex;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!_configurationService.didShowLiveWithArt()) {
        log.info('Show live with art intro');
        if (!mounted) {
          return;
        }
        unawaited(UIHelper.showLiveWithArtIntro(context));
      }
    });
    _initialTab = widget.payload.startedTab;
    _selectedIndex = _initialTab.index;
    _pageController = _getPageController(_selectedIndex);
    _pages = <Widget>[
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => injector<DailyWorkBloc>(),
          ),
          BlocProvider.value(value: injector<CanvasDeviceBloc>()),
        ],
        child: DailyWorkPage(
          key: dailyWorkKey,
        ),
      ),
      MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: FeralfileHomeBloc(injector()),
          ),
          BlocProvider.value(
            value: _subscriptionBloc..add(GetSubscriptionEvent()),
          ),
        ],
        child: FeralfileHomePage(
          key: feralFileHomeKey,
        ),
      ),
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _subscriptionBloc),
        ],
        child: OrganizeHomePage(
          key: _organizeHomeKey,
        ),
      ),
    ];

    /// precache playlist
    injector<ListPlaylistBloc>().add(ListPlaylistLoadPlaylist());
  }

  Future<void> refreshNotification() async {
    await injector<CustomerSupportService>().getChatThreads();
    await injector<CustomerSupportService>().processMessages();
  }

  @override
  Future<void> didPopNext() async {
    super.didPopNext();
    unawaited(_clientTokenService.refreshTokens());
    unawaited(refreshNotification());
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (!mounted) {
          return;
        }
        nftBloc.add(RequestIndexEvent(_clientTokenService.getAddresses()));
      });
    }
    // refresh playlist token here
    injector<ListPlaylistBloc>()
        .add(ListPlaylistLoadPlaylist(refreshDefaultPlaylist: true));
    if (_selectedIndex == HomeNavigatorTab.daily.index) {
      dailyWorkKey.currentState?.resumeDailyWork();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_fgbgSubscription?.cancel());
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColor.primaryBlack,
        body: SafeArea(
          top: false,
          bottom: false,
          child: BlocConsumer<NftCollectionBloc, NftCollectionBlocState>(
            bloc: nftBloc,
            listenWhen: (previous, current) =>
                _pageController == null ||
                previous.tokens.isEmpty && current.tokens.isNotEmpty ||
                previous.tokens.isNotEmpty && current.tokens.isEmpty,
            listener: (context, state) {
              if (state.tokens.isEmpty) {
                setState(() {
                  _initialTab = widget.payload.startedTab;
                });
              } else {}
            },
            buildWhen: (previous, current) {
              final shouldRebuild = _pageController == null;
              if (shouldRebuild) {
                _selectedIndex = _initialTab.index;
                _pageController?.dispose();
                _pageController = _getPageController(_selectedIndex);
              }
              return shouldRebuild;
            },
            builder: (context, state) {
              if (state.tokens.isEmpty) {
                if ([NftLoadingState.notRequested, NftLoadingState.loading]
                    .contains(state.state)) {
                  return Center(
                    child: loadingIndicator(valueColor: AppColor.white),
                  );
                }
              }
              return Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      return _pages[index];
                    },
                  ),
                  KeyboardVisibilityBuilder(
                    builder: (context, isKeyboardVisible) => isKeyboardVisible
                        ? const SizedBox()
                        : Positioned.fill(
                            bottom: 40,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: _buildBottomNavigationBar(context),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      );

  Widget _buildBottomNavigationBar(BuildContext context) {
    const selectedColor = AppColor.white;
    const unselectedColor = AppColor.disabledColor;
    const selectedColorFilter =
        ColorFilter.mode(selectedColor, BlendMode.srcIn);
    const unselectedColorFilter =
        ColorFilter.mode(unselectedColor, BlendMode.srcIn);
    const iconSize = 25.0;
    final bottomItems = [
      FFNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/images/discover.svg',
          height: iconSize,
          colorFilter: selectedColorFilter,
        ),
        unselectedIcon: SvgPicture.asset(
          'assets/images/discover.svg',
          height: iconSize,
          colorFilter: unselectedColorFilter,
        ),
        label: 'dailies',
      ),
      FFNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/images/set_icon.svg',
          height: iconSize,
          colorFilter: selectedColorFilter,
        ),
        unselectedIcon: SvgPicture.asset(
          'assets/images/set_icon.svg',
          height: iconSize,
          colorFilter: unselectedColorFilter,
        ),
        label: 'explore',
      ),
      const FFNavigationBarItem(
        icon: Icon(
          AuIcon.playlists,
          size: iconSize,
        ),
        unselectedIcon: Icon(
          AuIcon.playlists,
          size: iconSize,
        ),
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
        label: 'collection',
      ),
      FFNavigationBarItem(
        unselectedIcon: ValueListenableBuilder<List<int>?>(
          valueListenable:
              injector<CustomerSupportService>().numberOfIssuesInfo,
          builder: (
            BuildContext context,
            List<int>? numberOfIssuesInfo,
            Widget? child,
          ) =>
              iconWithRedDot(
            icon: SvgPicture.asset(
              'assets/images/icon_drawer.svg',
              height: iconSize,
              colorFilter: unselectedColorFilter,
            ),
            padding: const EdgeInsets.only(right: 2, top: 2),
            withReddot: numberOfIssuesInfo != null && numberOfIssuesInfo[1] > 0,
          ),
        ),
        icon: SvgPicture.asset(
          'assets/images/close.svg',
          colorFilter: const ColorFilter.mode(selectedColor, BlendMode.srcIn),
          height: iconSize,
          width: iconSize,
        ),
        selectedColor: unselectedColor,
        label: 'menu',
      ),
    ];
    return FFNavigationBar(
      items: bottomItems,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      backgroundColor: AppColor.auGreyBackground,
      onSelectTab: onItemTapped,
      currentIndex: _selectedIndex,
    );
  }

  PageController _getPageController(int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);
    injector<NavigationService>().setGlobalHomeTabController(pageController);
    return pageController;
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    if (widget.payload.startedTab != _initialTab) {
      await onItemTapped(widget.payload.startedTab.index);
    }
  }
}
