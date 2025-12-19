import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/home.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc_constants.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/home_page_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:flutter/material.dart';

class MobileControllerHomePage extends StatefulWidget {
  const MobileControllerHomePage({super.key, this.initialPageIndex = 0});

  final int initialPageIndex;

  @override
  State<MobileControllerHomePage> createState() =>
      _MobileControllerHomePageState();
}

class _MobileControllerHomePageState
    extends ObservingState<MobileControllerHomePage> {
  late int _currentPageIndex;
  late PageController _pageController;

  final _curatedChannelsBloc = injector<ChannelsBloc>(
      instanceName: ChannelsBlocInstance.curated.instanceName);
  final _curatedPlaylistsBloc = injector<PlaylistsBloc>(
      instanceName: PlaylistsBlocInstance.curated.instanceName);
  final _myPlaylistsBloc = injector<PlaylistsBloc>(
      instanceName: PlaylistsBlocInstance.my.instanceName);

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPageIndex;
    _pageController = PageController(initialPage: _currentPageIndex);

    // load channel and playlist
    _curatedChannelsBloc.add(const LoadChannelsEvent());
    _curatedPlaylistsBloc.add(LoadPlaylistsEvent());
    _myPlaylistsBloc.add(LoadPlaylistsEvent());

    // HomePageHelper.instance.onHomePageInit(context, this);
  }

  // dispose
  @override
  void dispose() {
    _pageController.dispose();
    HomePageHelper.instance.onHomePageDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        appBar: getDarkEmptyAppBar(Colors.transparent),
        backgroundColor: AppColor.auGreyBackground,
        extendBody: true,
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        body: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return HomeIndexPage();
  }
}
