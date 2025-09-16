import 'dart:async';

import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'user_all_own_collection_event.dart';
part 'user_all_own_collection_state.dart';

class UserAllOwnCollectionBloc
    extends Bloc<UserAllOwnCollectionEvent, UserAllOwnCollectionState> {
  StreamSubscription<List<AssetToken>>? _tokensStreamSub;
  Completer<void>? _activeCompleter;
  // Track latest query to optionally ignore redundant loads if needed in future
  LoadDynamicQueryEvent? _currentEvent;
  UserAllOwnCollectionBloc(this._tokensService)
      : super(const UserAllOwnCollectionState()) {
    on<LoadDynamicQueryEvent>(_onLoadDynamicQuery);
  }

  final NftTokensService _tokensService;

  Future<void> _onLoadDynamicQuery(
    LoadDynamicQueryEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      // If the same query is already being processed, ignore this event
      if (_tokensStreamSub != null &&
          _currentEvent != null &&
          _currentEvent!.dynamicQuery == event.dynamicQuery &&
          (event.lazy && _currentEvent!.lazy)) {
        log.info('LoadDynamicQueryEvent: same query, ignore');
        return;
      } else {
        log.info(
          'LoadDynamicQueryEvent: new query, proceed. Lazy: ${event.lazy}',
        );
      }
      _currentEvent = event;

      // Always emit loading state when starting to load
      emit(
        state.copyWith(
          status: UserAllOwnCollectionStatus.loading,
          isRefreshing: true && event.lazy,
        ),
      );

      // Cancel previous stream if any and advance sequence
      await _tokensStreamSub?.cancel();
      _tokensStreamSub = null;

      final owners = event.dynamicQuery.params.owners;

      // Use the new stream method with pagination from NftTokensService
      final stream = await _tokensService.getAssetTokensStream(
        owners,
        pageSize: 20, // Configurable page size
      );

      // Reset accumulated tokens handled by event handlers
      if (_activeCompleter?.isCompleted == false) {
        _activeCompleter?.complete('Cancelled by new load');
      }
      _activeCompleter = Completer<void>();
      if (event.lazy) {
        final List<AssetToken> accumulated = [];

        _tokensStreamSub = stream.listen(
          (tokens) {
            log.info('Received ${tokens.length} tokens');
            accumulated.addAll(tokens);
            emit(
              state.copyWith(
                assetTokens: List<AssetToken>.from(accumulated),
                isRefreshing: false,
                status: UserAllOwnCollectionStatus.loaded,
              ),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            log.info('Stream error: $error');
            emit(
              state.copyWith(
                status: UserAllOwnCollectionStatus.error,
                error: error.toString(),
                isRefreshing: false,
              ),
            );
            _activeCompleter?.completeError(error);
          },
          onDone: () {
            log.info('Stream done');
            emit(state.copyWith(status: UserAllOwnCollectionStatus.loaded));
            _activeCompleter?.complete();
          },
          cancelOnError: true,
        );
      } else {
        final List<AssetToken> collected = [];
        _tokensStreamSub = stream.listen(
          (tokens) {
            collected.addAll(tokens);
          },
          onError: (Object error, StackTrace stackTrace) {
            emit(
              state.copyWith(
                status: UserAllOwnCollectionStatus.error,
                error: error.toString(),
                isRefreshing: false,
              ),
            );
            _activeCompleter?.completeError(error);
          },
          onDone: () {
            emit(
              state.copyWith(
                assetTokens: List<AssetToken>.from(collected),
                isRefreshing: false,
                status: UserAllOwnCollectionStatus.loaded,
              ),
            );
            _activeCompleter?.complete();
          },
          cancelOnError: true,
        );
      }
      await _activeCompleter?.future;
    } catch (e) {
      log.info('LoadDynamicQueryEvent: error $e');
      emit(
        state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: e.toString(),
        ),
      );
    }
    log.info('LoadDynamicQueryEvent: completed');
    _currentEvent = null;
  }
}
