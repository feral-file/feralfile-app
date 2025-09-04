import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channels/bloc/channels_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage>
    with AutomaticKeepAliveClientMixin {
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
    _channelsBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _channelsBloc.add(const LoadMoreChannelsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocBuilder<ChannelsBloc, ChannelsState>(
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
          child: _buildContent(state),
        );
      },
    );
  }

  Widget _buildContent(ChannelsState state) {
    if (state.isLoading && state.channels.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.channels.isEmpty) {
      return ErrorView(
        error: 'Error loading channels: ${state.error}',
        onRetry: () => _channelsBloc.add(const LoadChannelsEvent()),
      );
    }

    return _buildChannelsList(state);
  }

  Widget _buildChannelsList(ChannelsState state) {
    final channels = state.channels;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      controller: _scrollController,
      itemCount: channels.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == channels.length) {
          return Column(
            children: [
              LoadMoreIndicator(isLoadingMore: isLoadingMore),
              const BottomSpacing(),
            ],
          );
        }

        final channel = channels[index];

        return Column(
          children: [
            ColoredBox(
              color: Colors.transparent,
              child: ChannelItem(channel: channel),
            ),
            if (index == channels.length - 1 && !hasMore) const BottomSpacing(),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
