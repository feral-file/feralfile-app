import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_api_response.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/widgets/playlist/playlist_section.dart';
import 'package:autonomy_flutter/service/dp1_feed_service.dart';
import 'package:autonomy_flutter/util/dp1_manifest_helper.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'channel_detail_event.dart';
part 'channel_detail_state.dart';

class ChannelDetailBloc extends Bloc<ChannelDetailEvent, ChannelDetailState> {
  ChannelDetailBloc({
    required this.channelId,
    required FeralFileDP1FeedService dp1playlistService,
  })  : _dp1playlistService = dp1playlistService,
        super(const ChannelDetailState()) {
    on<LoadChannelPlaylistsEvent>(_onLoadChannelPlaylists);
    on<LoadMoreChannelPlaylistsEvent>(_onLoadMoreChannelPlaylists);
    on<RefreshChannelPlaylistsEvent>(_onRefreshChannelPlaylists);
  }

  static const int _pageSize = 10;

  final String channelId;

  FeralFileDP1FeedService _dp1playlistService;

  Future<void> _onLoadChannelPlaylists(
    LoadChannelPlaylistsEvent event,
    Emitter<ChannelDetailState> emit,
  ) async {
    await _loadPlaylists(
      emit: emit,
      cursor: null,
    );
  }

  Future<void> _onLoadMoreChannelPlaylists(
    LoadMoreChannelPlaylistsEvent event,
    Emitter<ChannelDetailState> emit,
  ) async {
    // Prevent multiple simultaneous load more requests
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    await _loadPlaylists(
      emit: emit,
      cursor: state.cursor,
      isLoadMore: true,
    );
  }

  Future<void> _onRefreshChannelPlaylists(
    RefreshChannelPlaylistsEvent event,
    Emitter<ChannelDetailState> emit,
  ) async {
    await _loadPlaylists(
      emit: emit,
      cursor: null,
      isRefresh: true,
    );
  }

  Future<void> _loadPlaylists({
    required Emitter<ChannelDetailState> emit,
    required String? cursor,
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    try {
      // Emit appropriate loading state
      if (isLoadMore) {
        emit(state.copyWith(status: ChannelDetailStateStatus.loadingMore));
      } else {
        emit(state.copyWith(status: ChannelDetailStateStatus.loading));
      }

      final playlists = await _dp1playlistService.getCachedPlaylistsByChannelId(
        channelId,
      );
      final playlistsResponse = DP1PlaylistResponse(
        playlists,
        false,
        null,
      );

      // Collect all unique CIDs from playlists
      final cids = <String>[];
      for (final playlist in playlistsResponse.items) {
        for (final item in playlist.items) {
          if (item.cid != null) {
            cids.add(item.cid!);
          }
        }
      }

      // Load asset tokens for all items
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: cids);

      // Fetch DP1 manifests for all items
      final refs = <String>[];
      for (final playlist in playlistsResponse.items) {
        for (final item in playlist.items) {
          if (item.ref != null) {
            refs.add(item.ref!);
          }
        }
      }
      final manifests =
          await DP1ManifestHelper.instance.fetchDP1Manifests(refs);

      // Create PlaylistData list
      final playlistDataList = <PlaylistData>[];
      for (final playlist in playlistsResponse.items) {
        final items = <DP1NowDisplayingItem>[];
        for (final dp1Item in playlist.items) {
          final assetToken =
              assetTokens.firstWhereOrNull((t) => t.cid == dp1Item.cid);
          final dp1Manifest =
              dp1Item.ref != null ? manifests[dp1Item.ref] : null;

          items.add(
            DP1NowDisplayingItem(
              dp1Item: dp1Item,
              assetToken: assetToken,
              dp1Manifest: dp1Manifest,
            ),
          );
        }
        playlistDataList.add(
          PlaylistData(
            playlistReference: PlaylistReference(
              playlist: playlist,
              url: '',
            ),
            creator: 'Channel',
            items: items,
          ),
        );
      }

      final List<DP1Call> newPlaylists;
      final List<PlaylistData> newPlaylistDataList;
      if (isLoadMore) {
        newPlaylists = [...state.playlists, ...playlistsResponse.items];
        newPlaylistDataList = [...state.playlistData, ...playlistDataList];
      } else {
        newPlaylists = playlistsResponse.items;
        newPlaylistDataList = playlistDataList;
      }

      emit(
        state.copyWith(
          status: ChannelDetailStateStatus.loaded,
          playlists: newPlaylists,
          playlistData: newPlaylistDataList,
          hasMore: playlistsResponse.hasMore,
          cursor: playlistsResponse.cursor,
          error: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ChannelDetailStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
