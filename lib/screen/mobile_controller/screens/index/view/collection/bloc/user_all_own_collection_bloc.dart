import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/user_playlist_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

part 'user_all_own_collection_event.dart';
part 'user_all_own_collection_state.dart';

class UserAllOwnCollectionBloc
    extends Bloc<UserAllOwnCollectionEvent, UserAllOwnCollectionState> {
  final Map<Type, StreamSubscription<List<CompactedAssetToken>>?>
      _tokensStreamSubs = {};
  final Map<Type, Completer<void>?> _activeCompleters = {};
  DynamicQuery? _dynamicQuery;
  UserAllOwnCollectionBloc(this._tokensService)
      : super(const UserAllOwnCollectionState()) {
    on<RefreshAssetTokens>(_onRefreshLoad);
    on<UpdateDynamicQueryEvent>(_onUpdateDynamicQuery);
    on<ReloadAssetTokensFromIndexerDatabase>(
        _onReloadAssetTokensFromIndexerDatabase);
    on<ClearDataEvent>(_onClearData);
  }

  final NftTokensService _tokensService;

  void _onUpdateDynamicQuery(
    UpdateDynamicQueryEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) {
    log.info('[UserAllOwnCollectionBloc] onUpdateDynamicQuery');
    log.info(
        '[UserAllOwnCollectionBloc] dynamicQuery: ${event.dynamicQuery.toString()}');
    final isSameQuery = _dynamicQuery == event.dynamicQuery;
    _dynamicQuery = event.dynamicQuery;
    if (isSameQuery) {
      add(RefreshAssetTokens());
    } else {
      add(RefreshAssetTokens(shouldEmitLoading: true));
      add(ReloadAssetTokensFromIndexerDatabase());
    }
  }

  Future<void> _onRefreshLoad(
    RefreshAssetTokens event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    try {
      log.info('[UserAllOwnCollectionBloc][_onRefreshLoad] started');
      // If the same type is already being processed, ignore this event
      final subType = event.runtimeType;
      if (isRefreshAssetTokenFromDynamicQueryProcessing) {
        log.info(
            '[UserAllOwnCollectionBloc][_onRefreshLoad] refreshing, ignore');
        return;
      } else {
        log.info(
            '[UserAllOwnCollectionBloc][_onRefreshLoad] not refreshing, start refreshing');
      }
      if (event.shouldEmitLoading) {
        log.info(
            '[UserAllOwnCollectionBloc][_onRefreshLoad] emit loading state');
        emit(state.copyWith(status: UserAllOwnCollectionStatus.loading));
      }
      // cancel the previous stream
      await _tokensStreamSubs[subType]?.cancel();
      _tokensStreamSubs[subType] = null;

      // get the owners
      final addresses = injector<AddressService>().getAllAddresses();
      final dynamicQueryOwners = _dynamicQuery?.params.owners;

      final owners = [
        ...addresses,
        if (dynamicQueryOwners != null) ...dynamicQueryOwners
      ].toSet().toList();

      final lastUpdatedAt = injector<UserDp1PlaylistService>()
          .getAddressOldestLastRefreshedTime(addresses: owners);

      final newLastUpdatedAt = DateTime.now();

      final prevCompleter = _activeCompleters[subType];
      if (prevCompleter?.isCompleted == false) {
        prevCompleter?.complete('Cancelled by new refresh load');
      }
      final completer = Completer<void>();
      _activeCompleters[subType] = completer;

      // get the stream
      final stream = await _tokensService.refreshTokensInIsolate(
        {lastUpdatedAt.millisecondsSinceEpoch: owners},
        // owners,
        // pageSize: 20,
        // lastUpdatedAt: lastUpdatedAt,
      );

      final List<CompactedAssetToken> collected = [];

      _tokensStreamSubs[subType] = stream.listen(
        (tokens) {
          log.info('[${event.runtimeType}] Received ${tokens.length} tokens');
          collected.addAll(tokens);
          emit(state.copyWith(
            status: UserAllOwnCollectionStatus.loaded,
          ));
          add(ReloadAssetTokensFromIndexerDatabase());
        },
        onError: (Object error, StackTrace stackTrace) {
          log.info('[${event.runtimeType}] Stream error: $error');
          Sentry.captureException('Failed to refresh asset tokens: $error');
          _activeCompleters[subType]?.completeError(error);
        },
        onDone: () {
          emit(state.copyWith(
            status: UserAllOwnCollectionStatus.loaded,
          ));
          log.info(
              '[${event.runtimeType}] Stream done with total ${collected.length} tokens');
          _activeCompleters[subType]?.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
      _tokensStreamSubs[subType] = null;

      // update the last updated at
      await injector<UserDp1PlaylistService>().updateAddressLastRefreshedTime(
        addresses: owners,
        dateTime: newLastUpdatedAt,
      );

      add(ReloadAssetTokensFromIndexerDatabase());
    } catch (e) {
      log.info('[${event.runtimeType}] error $e');
      Sentry.captureException('Failed to refresh asset tokens: $e');
      if (event.shouldEmitLoading) {
        emit(state.copyWith(
          status: UserAllOwnCollectionStatus.error,
          error: e.toString(),
        ));
      }
    }
    log.info('[${event.runtimeType}] completed');
  }

  Future<void> _onReloadAssetTokensFromIndexerDatabase(
    ReloadAssetTokensFromIndexerDatabase event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    final owners = _dynamicQuery?.params.owners;
    if (owners == null) {
      emit(state.copyWith(addressAssetTokens: []));
      return;
    }
    final assetTokenGroupByAddress = injector<IndexerDatabaseAbstract>()
        .getGroupAssetTokensByOwnersGroupByAddress(
      owners: _dynamicQuery!.params.owners,
    );
    emit(
      state.copyWith(
        addressAssetTokens: assetTokenGroupByAddress
            .map(
              (e) => AddressAssetTokens(
                address: e.address,
                compactedAssetTokens: e.compactedAssetTokens,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _onClearData(
    ClearDataEvent event,
    Emitter<UserAllOwnCollectionState> emit,
  ) async {
    _tokensStreamSubs.clear();
    _activeCompleters.clear();
    _dynamicQuery = null;
    emit(const UserAllOwnCollectionState());
  }

  bool get isRefreshAssetTokenFromDynamicQueryProcessing =>
      _tokensStreamSubs[RefreshAssetTokens] != null ||
      _activeCompleters[RefreshAssetTokens]?.isCompleted == false;

  @override
  Future<void> close() {
    log.info('UserAllOwnCollectionBloc closing, cancelling streams');
    // TODO: implement close
    return super.close();
  }
}
