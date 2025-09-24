// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/nft_collection/services/configuration_service.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/nft_collection/utils/constants.dart';
import 'package:autonomy_flutter/nft_collection/utils/sorted_list.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:bloc/bloc.dart';

class NftCollectionBlocState {
  final NftLoadingState state;
  final AuList<CompactedAssetToken> tokens;

  final PageKey? nextKey;

  final bool isLoading;

  NftCollectionBlocState({
    required this.state,
    required this.tokens,
    this.nextKey,
    this.isLoading = false,
  });

  NftCollectionBlocState copyWith(
      {NftLoadingState? state,
      AuList<CompactedAssetToken>? tokens,
      required PageKey? nextKey,
      bool? isLoading,
      id}) {
    return NftCollectionBlocState(
      state: state ?? this.state,
      tokens: tokens ?? this.tokens,
      nextKey: nextKey,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NftCollectionBloc
    extends Bloc<NftCollectionBlocEvent, NftCollectionBlocState> {
  final NftTokensService tokensService;
  final IndexerDatabaseAbstract database;
  final NftCollectionPrefs prefs;
  final bool isSortedToken;
  final AddressService addressService;

  List<String> _debugTokenIds = [];

  List<String> get debugTokenIds => _debugTokenIds;

  static StreamController<NftCollectionBlocEvent> eventController =
      StreamController<NftCollectionBlocEvent>.broadcast();

  Future<List<String>> fetchManuallyTokens(List<String> indexerIds) async {
    if (indexerIds.isEmpty) {
      return indexerIds;
    }

    int offset = 0;

    while (offset < indexerIds.length) {
      final count = min(indexerTokensPageSize, indexerIds.length - offset);
      final ids = indexerIds.sublist(offset, offset + count);
      offset += count;
      final assets = await tokensService.fetchManualTokens(ids);
      if (assets.isNotEmpty) {
        add(UpdateTokensEvent(tokens: assets));
      }
    }

    return indexerIds;
  }

  NftCollectionBloc(
      this.tokensService, this.database, this.prefs, this.addressService,
      {this.isSortedToken = true})
      : super(
          NftCollectionBlocState(
            state: NftLoadingState.notRequested,
            tokens: isSortedToken ? SortedList() : NormalList(),
            nextKey: PageKey.init(),
          ),
        ) {
    // on<GetTokensByOwnerEvent>((event, emit) async {
    //   if (state.isLoading) {
    //     return;
    //   }
    //   final currentTokens = state.tokens.toList();
    //   if (event.pageKey == PageKey.init()) {
    //     currentTokens.clear();
    //   }
    //   state.nextKey?.isLoaded = true;
    //
    //   const limit = indexerTokensPageSize;
    //   final lastTime =
    //       event.pageKey.offset ?? DateTime.now().millisecondsSinceEpoch;
    //   final id = event.pageKey.id;
    //   NftCollection.logger
    //       .info("[NftCollectionBloc] GetTokensByOwnerEvent ${event.pageKey}");
    //   final activeAddress = await addressService.getAllAddresses(isHidden: false);
    //
    //   final assetTokens = event.contractAddress != null
    //       ? await database.assetTokenDao
    //           .findAllAssetTokensByOwnersAndContractAddress(
    //               activeAddress, event.contractAddress!, limit, lastTime, id)
    //       : await database.assetTokenDao
    //           .findAllAssetTokensByOwners(activeAddress, limit, lastTime, id);
    //
    //   final compactedAssetToken = assetTokens
    //       .map((e) => CompactedAssetToken.fromAssetToken(e))
    //       .toList();
    //
    //   final isLastPage = compactedAssetToken.length < indexerTokensPageSize;
    //   PageKey? nextKey;
    //
    //   if (compactedAssetToken.isNotEmpty) {
    //     nextKey = PageKey(
    //       offset:
    //           compactedAssetToken.last.lastActivityTime.millisecondsSinceEpoch,
    //       id: compactedAssetToken.last.id,
    //     );
    //   }
    //
    //   currentTokens.addAll(compactedAssetToken);
    //   currentTokens.unique((element) => element.id + element.owner);
    //
    //   NftCollection.logger.info(
    //       "[NftCollectionBloc] GetTokensByOwnerEvent ${compactedAssetToken.length}");
    //
    //   if (isLastPage) {
    //     emit(state.copyWith(
    //       tokens: currentTokens,
    //       nextKey: null,
    //       isLoading: false,
    //       state: NftLoadingState.done,
    //     ));
    //   } else {
    //     emit(
    //       state.copyWith(
    //         tokens: currentTokens,
    //         nextKey: nextKey,
    //         isLoading: false,
    //         state: NftLoadingState.loading,
    //       ),
    //     );
    //   }
    // });
    //
    // on<GetTokensBeforeByOwnerEvent>((event, emit) async {
    //   List<AssetToken> assetTokens = [];
    //   NftCollection.logger.info(
    //       "[NftCollectionBloc] GetTokensBeforeByOwnerEvent ${event.pageKey}");
    //   if (event.pageKey == null) {
    //     assetTokens = await database.assetTokenDao
    //         .findAllAssetTokensWithoutOffset(event.owners);
    //   } else {
    //     final id = event.pageKey!.id;
    //     final lastTime =
    //         event.pageKey!.offset ?? DateTime.now().millisecondsSinceEpoch;
    //     assetTokens = await database.assetTokenDao
    //         .findAllAssetTokensBeforeByOwners(event.owners, lastTime, id);
    //   }
    //   NftCollection.logger.info(
    //       "[NftCollectionBloc] GetTokensBeforeByOwnerEvent ${assetTokens.length}");
    //
    //   if (assetTokens.isEmpty) return;
    //   add(UpdateTokensEvent(tokens: assetTokens));
    // });
    //
    // on<RefreshNftCollectionByOwners>((event, emit) async {
    //   NftCollection.logger
    //       .info("[NftCollectionBloc] RefreshNftCollectionByOwners");
    //   final addresses = await _fetchAddresses();
    //   NftCollection.logger.fine("[NftCollectionBloc] UpdateAddresses. "
    //       "Addresses: ${addresses.map((e) => e.address).toList()}");
    //   final debugTokens = event.debugTokens.unique((e) => e) ?? [];
    //   final debugTokensChanged =
    //       !setEquals(debugTokens.toSet(), _debugTokenIds.toSet());
    //   if (debugTokensChanged) {
    //     _debugTokenIds = debugTokens;
    //     NftCollection.logger.info("[NftCollectionBloc] UpdateAddresses. "
    //         "debugTokenIds: $_debugTokenIds");
    //   }
    //
    //   try {
    //     final mapAddresses = _mapAddressesByLastRefreshedTime(addresses);
    //
    //     fetchManuallyTokens(_debugTokenIds);
    //
    //     NftCollection.logger.info(
    //         "[NftCollectionBloc][start] _tokensService.refreshTokensInIsolate");
    //     final stream = await tokensService.refreshTokensInIsolate(mapAddresses);
    //     if (tokensService.isRefreshAllTokensListen) return;
    //
    //     stream.listen((event) async {
    //       NftCollection.logger.info("[Stream.refreshTokensInIsolate] getEvent");
    //
    //       List<AssetToken> addingTokens = [];
    //       if (event.isNotEmpty) {
    //         NftCollection.logger.info(
    //             "[Stream.refreshTokensInIsolate] UpdateTokensEvent ${event.length} tokens");
    //         if (state.nextKey?.offset != null) {
    //           addingTokens = event
    //               .where(
    //                 (element) =>
    //                     element.lastActivityTime.millisecondsSinceEpoch >=
    //                     state.nextKey!.offset!,
    //               )
    //               .toList();
    //         } else {
    //           addingTokens = event;
    //         }
    //       }
    //       if (addingTokens.isNotEmpty || debugTokensChanged) {
    //         add(UpdateTokensEvent(
    //           state: NftLoadingState.loading,
    //           tokens: addingTokens,
    //         ));
    //       }
    //     }, onDone: () async {
    //       NftCollection.logger
    //           .info("[Stream.refreshTokensInIsolate] getEvent Done");
    //       if (state.state == NftLoadingState.done) return;
    //       add(UpdateTokensEvent(state: NftLoadingState.done));
    //     });
    //   } catch (exception) {
    //     NftCollection.logger.info(
    //         "[NftCollectionBloc] RefreshNftCollectionByOwners Error: ${exception.toString()}");
    //     add(UpdateTokensEvent(state: NftLoadingState.error));
    //
    //     NftCollection.logger.warning("Error: $exception");
    //   }
    // });
    //
    // on<RefreshNftCollectionByIDs>((event, emit) async {
    //   NftCollection.logger
    //       .info("[NftCollectionBloc] RefreshNftCollectionByIDs");
    //   if (event.debugTokenIds?.isNotEmpty ?? false) {
    //     _debugTokenIds = event.debugTokenIds ?? [];
    //     fetchManuallyTokens(_debugTokenIds);
    //   }
    //   if (event.ids?.isEmpty ?? true) {
    //     emit(state.copyWith(
    //       nextKey: state.nextKey,
    //       tokens: SortedList(),
    //       state: NftLoadingState.done,
    //     ));
    //     return;
    //   }
    //
    //   List<AssetToken> assetTokens =
    //       await database.assetTokenDao.findAllAssetTokensByTokenIDs(event.ids!);
    //   if (event.shouldFetchIfNotExistsInCache) {
    //     final assetTokensNotInDb = event.ids!
    //         .where((element) => !assetTokens.any((e) => e.id == element))
    //         .toList();
    //     final assetTokensNotInDbList =
    //         await tokensService.fetchManualTokens(assetTokensNotInDb);
    //     assetTokens.addAll(assetTokensNotInDbList);
    //   }
    //   final activeAddress = addressService.getAllAddresses(isHidden: false);
    //   assetTokens.removeWhere((element) =>
    //       !activeAddress.contains(element.owner) && element.isManual != true);
    //   final compactedAssetToken = assetTokens
    //       .map((e) => CompactedAssetToken.fromAssetToken(e))
    //       .toList();
    //   final tokens = state.tokens.toList();
    //   tokens.addAll(compactedAssetToken);
    //   tokens.unique((element) => element.id + element.owner);
    //
    //   emit(state.copyWith(
    //     nextKey: state.nextKey,
    //     tokens: tokens,
    //     state: NftLoadingState.done,
    //   ));
    // });
    //
    // on<UpdateTokensEvent>((event, emit) async {
    //   if (event.tokens.isEmpty && event.state == null) return;
    //   NftCollection.logger
    //       .info("[NftCollectionBloc] UpdateTokensEvent ${event.tokens.length}");
    //   final tokens = state.tokens.toList();
    //   if (event.tokens.isNotEmpty) {
    //     final compactedAssetToken = event.tokens
    //         .map((e) => CompactedAssetToken.fromAssetToken(e))
    //         .toList();
    //     tokens.addAll(compactedAssetToken);
    //     tokens.unique((element) => element.id + element.owner);
    //   }
    //
    //   final activeAddress = await addressService.getAllAddresses(isHidden: false);
    //
    //   tokens.removeWhere((element) =>
    //       !activeAddress.contains(element.owner) &&
    //           element.isDebugged != true ||
    //       (element.isDebugged == true && !_debugTokenIds.contains(element.id)));
    //
    //   emit(
    //     state.copyWith(
    //       state: event.state,
    //       tokens: tokens,
    //       nextKey: state.nextKey,
    //     ),
    //   );
    // });
    //
    // on<ReloadEvent>((event, emit) async {
    //   emit(state.copyWith(nextKey: state.nextKey));
    // });
    //
    // on<RequestIndexEvent>((event, emit) async {
    //   tokensService.reindexAddresses(_filterAddresses(event.addresses));
    // });
  }

  @override
  void add(NftCollectionBlocEvent event) {
    // ignore: avoid_print
    print('NftCollectionBloc event: $event');
    // super.add(event);
  }

  // Map<int, List<String>> _mapAddressesByLastRefreshedTime(
  //     List<AddressCollection> addresses) {
  //   if (addresses.isEmpty) return {};
  //   final result = <int, List<String>>{};
  //
  //   for (var address in addresses) {
  //     int key = address.lastRefreshedTime.millisecondsSinceEpoch;
  //     if (result[key] == null) {
  //       result[key] = [address.address];
  //     } else {
  //       result[key]?.add(address.address);
  //     }
  //   }
  //
  //   return result;
  // }
  //
  // Future<List<AddressCollection>> _fetchAddresses() async {
  //   final addressCollection = await addressService.getAllAddresses();
  //   return _filterAddressCollection(addressCollection);
  // }
  //
  // List<AddressCollection> _filterAddressCollection(
  //     List<AddressCollection> addresses) {
  //   return addresses
  //       .where((element) => element.address.trim().isNotEmpty)
  //       .toList();
  // }
  //
  // List<String> _filterAddresses(List<String> addresses) {
  //   return addresses.map((e) => e.trim()).whereNot((e) => e.isEmpty).toList();
  // }
}
