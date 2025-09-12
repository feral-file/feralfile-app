import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/service/dp1_playlist_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'works_event.dart';
part 'works_state.dart';

class WorksBloc extends Bloc<WorksEvent, WorksState> {
  WorksBloc({
    required DP1FeedService dp1PlaylistService,
    required NftIndexerService indexerService,
  })  : _dp1PlaylistService = dp1PlaylistService,
        _indexerService = indexerService,
        super(const WorksState()) {
    on<LoadWorksEvent>(_onLoadWorks);
    on<LoadMoreWorksEvent>(_onLoadMoreWorks);
    on<RefreshWorksEvent>(_onRefreshWorks);
  }

  static const int _pageSize = 10;

  final DP1FeedService _dp1PlaylistService;
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

      final worksResponse = await _dp1PlaylistService.getPlaylistItems(
        cursor: cursor,
        limit: _pageSize,
      );

      final newWorksItems = worksResponse.items;
      final assetTokens = await _indexerService.getAssetTokens(newWorksItems);

      final List<AssetToken> newAssetTokens;
      if (isLoadMore) {
        newAssetTokens = [...state.assetTokens, ...assetTokens];
      } else {
        newAssetTokens = assetTokens;
      }

      emit(
        state.copyWith(
          status: WorksStateStatus.loaded,
          assetTokens: newAssetTokens,
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
