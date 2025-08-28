import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/channel.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/bloc/channel_detail_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/detail_page_appbar.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_list_view.dart';
import 'package:autonomy_flutter/service/dp1_playlist_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChannelDetailPagePayload {
  ChannelDetailPagePayload({
    required this.channel,
    this.backTitle = 'Channels',
  });

  final Channel channel;
  final String backTitle;
}

class ChannelDetailPage extends StatefulWidget {
  const ChannelDetailPage({required this.payload, super.key});

  final ChannelDetailPagePayload payload;

  @override
  State<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends State<ChannelDetailPage>
    with AutomaticKeepAliveClientMixin {
  late final ChannelDetailBloc _channelDetailBloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _channelDetailBloc = ChannelDetailBloc(
      channel: widget.payload.channel,
      dp1playlistService: injector<Dp1PlaylistService>(),
    );
    _channelDetailBloc.add(const LoadChannelPlaylistsEvent());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _channelDetailBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels + 100 >=
        _scrollController.position.maxScrollExtent) {
      _channelDetailBloc.add(const LoadMoreChannelPlaylistsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: DetailPageAppBar(
        title: widget.payload.backTitle,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: UIConstants.detailPageHeaderPadding),
            ChannelItem(
              channel: widget.payload.channel,
              clickable: false,
            ),
            const SizedBox(height: UIConstants.detailPageHeaderPadding),
            Expanded(
              child: BlocBuilder<ChannelDetailBloc, ChannelDetailState>(
                bloc: _channelDetailBloc,
                builder: (context, state) => RefreshIndicator(
                  onRefresh: () async {
                    _channelDetailBloc.add(
                      const RefreshChannelPlaylistsEvent(),
                    );
                    await _channelDetailBloc.stream.firstWhere(
                      (state) => state.isLoaded || state.isError,
                    );
                  },
                  backgroundColor: AppColor.primaryBlack,
                  color: AppColor.white,
                  child: _buildContent(context, state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChannelDetailState state) {
    if (state.isLoading && state.playlists.isEmpty) {
      return const LoadingView();
    }

    if (state.isError && state.playlists.isEmpty) {
      return ErrorView(
        error: 'Error loading playlists: ${state.error}',
        onRetry: () => _channelDetailBloc.add(
          const LoadChannelPlaylistsEvent(),
        ),
      );
    }
    return _buildPlaylists(state);
  }

  Widget _buildPlaylists(ChannelDetailState state) {
    final playlists = state.playlists;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;

    return PlaylistListView(
      playlists: playlists,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      scrollController: _scrollController,
      channel: widget.payload.channel,
      channelVisible: false,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
