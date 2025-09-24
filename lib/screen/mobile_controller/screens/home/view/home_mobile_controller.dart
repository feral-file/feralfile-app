import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/collection/bloc/user_all_own_collection_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/index.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/home_page_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  final _channelsBloc = injector<ChannelsBloc>();
  final _playlistsBloc = injector<PlaylistsBloc>();
  final _userAllOwnCollectionBloc = injector<UserAllOwnCollectionBloc>();

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialPageIndex;
    _pageController = PageController(initialPage: _currentPageIndex);

    // load channel and playlist
    _channelsBloc.add(const LoadChannelsEvent());
    _playlistsBloc.add(const LoadPlaylistsEvent());

    // final dynamicQuery = injector<UserAllOwnCollectionBloc>()
    //     .state
    //     .dynamicQuery
    //     .copyWith(
    //         params:
    //             injector<UserAllOwnCollectionBloc>().state.dynamicQuery.params);
    // _userAllOwnCollectionBloc.add(RefreshAssetTokenFromDynamicQuery());
    // injector<MeiliSearchBloc>().add(MeiliSearchQueryChanged(''));

    HomePageHelper.instance.onHomePageInit(context, this);
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
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _channelsBloc),
        BlocProvider.value(value: _playlistsBloc),
      ],
      child: ListDirectoryPage(
        key: directoryPageGlobalKey,
      ),
    );
  }
}
