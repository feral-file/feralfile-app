import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/all_channels_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel/channel_section.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final ScrollController _scrollController = ScrollController();
  late final ChannelsBloc _curatedChannelsBloc;
  late final ChannelsBloc _myChannelsBloc;
  late final ChannelsBloc _globalChannelsBloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _curatedChannelsBloc = injector<ChannelsBloc>(
      instanceName: ChannelsBlocInstance.curated.instanceName,
    );
    _myChannelsBloc = injector<ChannelsBloc>(
      instanceName: ChannelsBlocInstance.me.instanceName,
    );
    _globalChannelsBloc = injector<ChannelsBloc>(
      instanceName: ChannelsBlocInstance.global.instanceName,
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
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
    _curatedChannelsBloc.add(const RefreshChannelsEvent());
    _myChannelsBloc.add(const RefreshChannelsEvent());
    _globalChannelsBloc.add(const RefreshChannelsEvent());
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _curatedChannelsBloc.add(const LoadMoreChannelsEvent());
      _myChannelsBloc.add(const LoadMoreChannelsEvent());
      _globalChannelsBloc.add(const LoadMoreChannelsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      shrinkWrap: true,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // _buildMyChannels(),
        // const SliverToBoxAdapter(
        //   child: SizedBox(height: 50),
        // ),
        _buildCuratedChannels(),
        const SliverToBoxAdapter(
          child: SizedBox(height: 50),
        ),
        // _buildGlobalChannels(),
      ],
    );
  }

  Widget _buildCuratedChannels() {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      bloc: _curatedChannelsBloc,
      builder: (context, state) => _buildContent(state, _curatedChannelsBloc),
    );
  }

  Widget _buildMyChannels() {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      bloc: _myChannelsBloc,
      builder: (context, state) => _buildContent(state, _myChannelsBloc),
    );
  }

  Widget _buildGlobalChannels() {
    return BlocBuilder<ChannelsBloc, ChannelsState>(
      bloc: _globalChannelsBloc,
      builder: (context, state) => _buildContent(state, _globalChannelsBloc),
    );
  }

  Widget _buildContent(ChannelsState state, ChannelsBloc channelsBloc) {
    if (state.isLoading && state.channels.isEmpty) {
      return const SliverToBoxAdapter(
        child: LoadingView(),
      );
    }
    if (state.isError && state.channels.isEmpty) {
      return SliverToBoxAdapter(
        child: ErrorView(
          error: 'Error loading channels: ${state.error}',
          onRetry: () => channelsBloc.add(const LoadChannelsEvent()),
        ),
      );
    }

    return _buildChannels(state, channelsBloc);
  }

  Widget _buildChannels(ChannelsState state, ChannelsBloc channelsBloc) {
    final channelType = channelsBloc.channelType;
    // only get the first 5 channels for section
    final channelDataList = state.channelData.safeSublist(0, 5);
    final hasMore = state.hasMore;

    return SliverList.builder(
      itemCount: 1,
      itemBuilder: (context, index) => Column(
        children: [
          ChannelSection(
            sectionName: channelType.name,
            sectionIcon: SvgPicture.asset(
              channelType.icon,
              width: 12,
              height: 12,
              colorFilter: const ColorFilter.mode(
                PrimitivesTokens.colorsGrey,
                BlendMode.srcIn,
              ),
            ),
            channels: channelDataList,
            hasMore: hasMore,
            onViewAllTap: () {
              Navigator.of(context).pushNamed(
                AppRouter.allChannelsPage,
                arguments: AllChannelsPagePayload(channelType: channelType),
              );
            },
            onChannelItemTap: (item) {
              final assetToken = item.assetToken;
              if (assetToken != null) {
                injector<NavigationService>().navigateTo(
                  AppRouter.artworkDetailsPage,
                  arguments:
                      ArtworkDetailPayload(ArtworkIdentity(assetToken.cid)),
                );
              }
            },
            onLoadMore: (channel) {
              channelsBloc.add(LoadMoreChannelItemsEvent(
                channelId: channel.channelReference.channel.id,
              ));
            },
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
