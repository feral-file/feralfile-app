import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel/channel_list_row.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// All Channels Page - Displays list of all channels with descriptions
///
/// [channelType] - The type of channels to display
///   - [ChannelType.curated] - Displays all curated channels
///   - [ChannelType.me] - Displays all channels created by the user
///   - [ChannelType.global] - Displays all global channels
///

class AllChannelsPagePayload {
  const AllChannelsPagePayload({
    required this.channelType,
  });

  final ChannelType channelType;
}

class AllChannelsPage extends StatefulWidget {
  const AllChannelsPage({super.key, required this.payload});

  final AllChannelsPagePayload payload;

  @override
  State<AllChannelsPage> createState() => _AllChannelsPageState();
}

class _AllChannelsPageState extends State<AllChannelsPage> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  late final ChannelsBloc _channelsBloc;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _channelsBloc = context.read<ChannelsBloc>();
    _channelsBloc.add(const LoadChannelsEvent());
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
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _channelsBloc.add(const LoadMoreChannelsEvent());
    }
  }

  @override
  void didUpdateWidget(AllChannelsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.channelType != widget.payload.channelType) {
      _channelsBloc.add(const LoadChannelsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: const MainAppBar(
        backTitle: 'Index',
      ),
      body: SafeArea(
        child: BlocBuilder<ChannelsBloc, ChannelsState>(
          bloc: _channelsBloc,
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () async {
                _channelsBloc.add(const RefreshChannelsEvent());
                // Wait for the refresh to complete
                await _channelsBloc.stream.firstWhere(
                  (state) => state.isLoaded || state.isError,
                );
              },
              backgroundColor: AppColor.primaryBlack,
              color: AppColor.white,
              child: _buildContent(context, state),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChannelsState state) {
    if (state.isLoading && state.channels.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.channels.isEmpty) {
      return ErrorView(
        error: 'Error loading channels: ${state.error}',
        onRetry: () => _channelsBloc.add(const LoadChannelsEvent()),
      );
    }

    return _buildChannelsList(context, state);
  }

  Widget _buildChannelsList(BuildContext context, ChannelsState state) {
    final theme = Theme.of(context);
    final channelReferences = state.channels;

    if (channelReferences.isEmpty) {
      return Center(
        child: Text(
          'No channels found',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: 21),
        ),
        // ChannelList
        SliverList.builder(
          itemBuilder: (context, index) {
            final channelReference = channelReferences[index];
            return ChannelListRow(
              channelReference: channelReference,
              onItemTap: (item) {
                final assetToken = item.assetToken;
                if (assetToken != null) {
                  injector<NavigationService>().navigateTo(
                    AppRouter.artworkDetailsPage,
                    arguments: ArtworkDetailPayload(
                      ArtworkIdentity(assetToken.cid),
                    ),
                  );
                }
              },
            );
          },
          itemCount: channelReferences.length,
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: LoadMoreIndicator(
              isLoadingMore: true,
            ),
          ),
        const SliverToBoxAdapter(
          child: BottomSpacing(),
        ),
      ],
    );
  }
}
