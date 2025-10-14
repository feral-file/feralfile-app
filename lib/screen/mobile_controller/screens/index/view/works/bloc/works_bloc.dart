import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_item.dart';
import 'package:autonomy_flutter/util/feed_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'works_event.dart';
part 'works_state.dart';

class WorksBloc extends Bloc<WorksEvent, WorksState> {
  WorksBloc({
    required NftIndexerService indexerService,
  })  : _indexerService = indexerService,
        super(const WorksState()) {
    on<LoadWorksEvent>(_onLoadWorks);
    on<LoadMoreWorksEvent>(_onLoadMoreWorks);
    on<RefreshWorksEvent>(_onRefreshWorks);
  }

  static const int _pageSize = 10;

  final NftIndexerService _indexerService;

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
            assetTokens: [],
            dp1Items: [],
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
      final assetTokens = await _indexerService.getAssetTokens(items);

      final List<AssetToken> newAssetTokens;
      final List<DP1Item> newDP1Items;
      if (isLoadMore) {
        newAssetTokens = [...state.assetTokens, ...assetTokens];
        newDP1Items = [...state.dp1Items, ...items];
      } else {
        newAssetTokens = assetTokens;
        newDP1Items = items;
      }

      emit(
        state.copyWith(
          status: WorksStateStatus.loaded,
          assetTokens: newAssetTokens,
          dp1Items: newDP1Items,
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
