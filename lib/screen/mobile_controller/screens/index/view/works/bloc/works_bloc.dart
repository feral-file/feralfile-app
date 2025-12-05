import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/now_displaying_object.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/dp1_manifest_helper.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'works_event.dart';
part 'works_state.dart';

class WorksBloc extends Bloc<WorksEvent, WorksState> {
  WorksBloc() : super(const WorksState()) {
    on<LoadWorksEvent>(_onLoadWorks);
    on<LoadMoreWorksEvent>(_onLoadMoreWorks);
    on<RefreshWorksEvent>(_onRefreshWorks);
  }

  static const int _pageSize = 10;

  Future<void> _onLoadWorks(
    LoadWorksEvent event,
    Emitter<WorksState> emit,
  ) async {
    await _loadWorks(
      emit: emit,
      cursor: null,
    );
  }

  Future<void> _onLoadMoreWorks(
    LoadMoreWorksEvent event,
    Emitter<WorksState> emit,
  ) async {
    // Prevent multiple simultaneous load more requests
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    await _loadWorks(
      emit: emit,
      cursor: state.cursor,
      isLoadMore: true,
    );
  }

  Future<void> _onRefreshWorks(
    RefreshWorksEvent event,
    Emitter<WorksState> emit,
  ) async {
    await _loadWorks(
      emit: emit,
      cursor: null,
      isRefresh: true,
    );
  }

  Future<void> _loadWorks({
    required Emitter<WorksState> emit,
    required String? cursor,
    bool isLoadMore = false,
    bool isRefresh = false,
  }) async {
    try {
      // Emit appropriate loading state
      if (isLoadMore) {
        emit(state.copyWith(status: WorksStateStatus.loadingMore));
      } else {
        emit(state.copyWith(status: WorksStateStatus.loading));
      }

      final remoteConfigChannels =
          injector<FeralFileFeedManager>().remoteConfigChannels;
      if (remoteConfigChannels.isEmpty) {
        emit(state.copyWith(
            status: WorksStateStatus.loaded,
            nowDisplayingItems: [],
            hasMore: false,
            cursor: null,
            error: ''));
        return;
      }

      final worksResponse = await injector<FeralFileFeedManager>()
          .getPlaylistItemsByListOfChannels(
        channels: remoteConfigChannels,
        cursor: cursor,
        limit: _pageSize,
      );

      final items = worksResponse.items;
      final cids = items.map((e) => e.cid).whereType<String>().toList();
      final assetTokens =
          await injector<NftTokensService>().getManualTokens(cids: cids);

      // Fetch DP1 manifests for page items
      final refs = items.map((e) => e.ref).whereType<String>().toList();
      final manifests =
          await DP1ManifestHelper.instance.fetchDP1Manifests(refs);

      // Build nowDisplayingItems list
      final pageNowDisplayingItems = <DP1NowDisplayingItem>[];
      for (int i = 0; i < items.length; i++) {
        final dp1Item = items[i];
        final assetToken =
            assetTokens.firstWhereOrNull((e) => e.cid == dp1Item.cid);
        final dp1Manifest = manifests[dp1Item.ref];
        pageNowDisplayingItems.add(
          DP1NowDisplayingItem(
            dp1Item: dp1Item,
            assetToken: assetToken,
            dp1Manifest: dp1Manifest,
          ),
        );
      }

      final List<DP1NowDisplayingItem> newNowDisplayingItems;
      if (isLoadMore) {
        newNowDisplayingItems = [
          ...state.nowDisplayingItems,
          ...pageNowDisplayingItems
        ];
      } else {
        newNowDisplayingItems = pageNowDisplayingItems;
      }

      emit(
        state.copyWith(
          status: WorksStateStatus.loaded,
          nowDisplayingItems: newNowDisplayingItems,
          cursor: worksResponse.cursor,
          hasMore: worksResponse.hasMore,
          error: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: WorksStateStatus.error,
          error: e.toString(),
        ),
      );
    }
  }
}
