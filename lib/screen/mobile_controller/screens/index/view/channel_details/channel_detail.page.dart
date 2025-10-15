import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/channel_details/bloc/channel_detail_bloc.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/channel_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/error_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/load_more_indicator.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/loading_view.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist_item.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:autonomy_flutter/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChannelDetailPagePayload {
  ChannelDetailPagePayload({
    required this.channelReference,
    this.backTitle = 'Channels',
  });

  final ChannelReference channelReference;
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

    final url = widget.payload.channelReference.url;
    final feedService =
        injector<FeralFileFeedManager>().getFeedServiceByUrl(url);
    _channelDetailBloc = ChannelDetailBloc(
      channelId: widget.payload.channelReference.channel.id,
      dp1playlistService: feedService as FeralFileDP1FeedService,
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
      appBar: CustomAppBar(
        backTitle: widget.payload.backTitle,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _channelDetailBloc.add(
              const RefreshChannelPlaylistsEvent(),
            );
          },
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: CustomScrollView(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                  child: SizedBox(height: UIConstants.detailPageHeaderPadding)),
              SliverToBoxAdapter(
                  child: ChannelItem(
                channelReference: widget.payload.channelReference,
                clickable: false,
              )),
              const SliverToBoxAdapter(
                  child: SizedBox(height: UIConstants.detailPageHeaderPadding)),
              BlocBuilder<ChannelDetailBloc, ChannelDetailState>(
                bloc: _channelDetailBloc,
                builder: (context, state) => _buildContent(context, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChannelDetailState state) {
    if (state.isLoading && state.playlists.isEmpty) {
      return const SliverToBoxAdapter(child: LoadingView());
    }

    if (state.isError && state.playlists.isEmpty) {
      return SliverToBoxAdapter(
          child: ErrorView(
        error: 'Error loading playlists: ${state.error}',
        onRetry: () => _channelDetailBloc.add(
          const LoadChannelPlaylistsEvent(),
        ),
      ));
    }
    return _buildPlaylists(state);
  }

  SliverList _buildPlaylists(ChannelDetailState state) {
    final playlists = state.playlists;
    final hasMore = state.hasMore;
    final isLoadingMore = state.isLoadingMore;
    final channelReference = widget.payload.channelReference;
    final url = channelReference.url;
    final playlistReferences = playlists
        .map((playlist) => PlaylistReference(playlist: playlist, url: url))
        .toList();

    return playlistSliverListView(
      playlists: playlistReferences,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
      scrollController: _scrollController,
      channelVisible: false,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

SliverList playlistSliverListView({
  required List<PlaylistReference> playlists,
  bool hasMore = false,
  bool isLoadingMore = false,
  ScrollController? scrollController,
  bool channelVisible = true,
  bool isFromPlaylistsPage = false,
}) {
  return SliverList.builder(
    itemBuilder: (context, index) {
      if (index == playlists.length) {
        return Column(
          children: [
            LoadMoreIndicator(isLoadingMore: isLoadingMore),
            const BottomSpacing(),
          ],
        );
      }

      final playlist = playlists[index];
      final service =
          injector<FeralFileFeedManager>().getFeedServiceByUrl(playlist.url);
      ChannelReference? channelReference;
      if (service is FeralFileDP1FeedService) {
        final channel = service.getChannelByPlaylistId(playlist.playlist.id);
        if (channel != null) {
          channelReference =
              ChannelReference(channel: channel, url: playlist.url);
        }
      }

      return Column(
        children: [
          PlaylistItem(
            playlistReference: playlist,
            channelReference: channelReference,
            isFromPlaylistsPage: isFromPlaylistsPage,
            channelVisible: channelVisible,
          ),
          if (index == playlists.length - 1 && !hasMore) const BottomSpacing(),
        ],
      );
    },
    itemCount: playlists.length + (hasMore ? 1 : 0),
  );
}
