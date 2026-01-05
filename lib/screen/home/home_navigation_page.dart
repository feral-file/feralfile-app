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
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home.dart';
import 'package:autonomy_flutter/screen/feralfile_home/feralfile_home_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';

class HomeNavigationPagePayload {
  const HomeNavigationPagePayload({
    HomeNavigatorTab? startedTab,
  }) : startedTab = startedTab ?? HomeNavigatorTab.explore;

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
  late Timer? _timer;
  final _remoteConfig = injector<RemoteConfigService>();
  late HomeNavigatorTab _initialTab;
  late FeralfileHomeBloc _feralfileHomeBloc;

  StreamSubscription<FGBGType>? _fgbgSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  Future<void> onItemTapped(int index) async {
    if (index < 1) {
      // handle scroll to top when tap on the same tab
      if (_selectedIndex == index && index == HomeNavigatorTab.explore.index) {
        feralFileHomeKey.currentState?.scrollToTop();
      }
      setState(() {
        _selectedIndex = index;
      });
      _pageController?.jumpToPage(_selectedIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    _initialTab = widget.payload.startedTab;
    _feralfileHomeBloc = FeralfileHomeBloc(injector());

    WidgetsBinding.instance.addObserver(this);
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _feralfileHomeBloc.close();
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
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(
                value: _feralfileHomeBloc,
              ),
            ],
            child: FeralfileHomePage(
              key: feralFileHomeKey,
            ),
          ),
        ),
      );

  Future<void> _handleForeBackground(FGBGType event) async {
    switch (event) {
      case FGBGType.foreground:
        unawaited(_handleForeground());
        memoryValues.isForeground = true;
      case FGBGType.background:
        memoryValues.isForeground = false;
    }
  }

  Future<void> _handleForeground() async {
    memoryValues.inForegroundAt = DateTime.now();
    await injector<ConfigurationService>().reload();
    await _remoteConfig.loadConfigs(forceRefresh: true);
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    if (widget.payload.startedTab != _initialTab) {
      await onItemTapped(widget.payload.startedTab.index);
    }
  }
}
