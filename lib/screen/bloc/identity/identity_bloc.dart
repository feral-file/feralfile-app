//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/service/hive_store_service.dart';
import 'package:autonomy_flutter/util/log.dart';

part 'identity_state.dart';

class IndexerIdentityStore extends HiveStoreObjectServiceImpl<IndexerIdentity> {
  IndexerIdentityStore() : super(key: _key);
  static const String _key = 'indexerIdentityStoreKey';

  @override
  final key = _key;

  @override
  Future<void> init() async {
    await super.init();
  }
}

class IdentityBloc extends AuBloc<IdentityEvent, IdentityState> {
  IdentityBloc(this._identityStore, this._indexerService)
      : super(IdentityState({})) {
    on<GetIdentityEvent>((event, emit) async {
      try {
        final resultFromDB = <String, String>{};
        final unknownIdentities = <String>[];

        // Try to get from the database first.
        await Future.forEach<String>(event.addresses, (address) async {
          if (address.contains(' ') || address.length < 36) {
            return;
          }

          final identity = _identityStore.get(address);
          if (identity != null) {
            if (identity.queriedAt
                    .add(localIdentityCacheDuration)
                    .compareTo(DateTime.now()) >=
                0) {
              if (identity.name.isEmpty) {
                unknownIdentities.add(address);
                return;
              }
              // If the identity cache are still ok, add to the map
              resultFromDB[address] = identity.name;
            } else {
              // Remove those item from the database
              await _identityStore.delete(identity.hiveId);
              // Re-query from the API
              unknownIdentities.add(address);
            }
          } else {
            unknownIdentities.add(address);
          }
        });
        if (resultFromDB.isNotEmpty) {
          emit(IdentityState(resultFromDB));
        }

        // Stop if nothing obsolete
        if (unknownIdentities.isEmpty) {
          return;
        }
        final resultFromAPI = <String, String>{};
        // Get from the API
        await Future.forEach(unknownIdentities, (address) async {
          try {
            final request = QueryIdentityRequest(account: address);
            final identity = await _indexerService.getIdentity(request);
            final indexerIdentity = IndexerIdentity(
              identity.accountNumber,
              identity.blockchain,
              identity.name,
            );
            resultFromAPI[address] = identity.name;
            await _identityStore.save(indexerIdentity, indexerIdentity.hiveId);
          } catch (_) {
            // Ignore bad API responses
            return;
          }
        });

        if (resultFromAPI.isNotEmpty) {
          final result = <String, String>{}
            ..addAll(resultFromDB)
            ..addAll(resultFromAPI);
          emit(IdentityState(result));
        }
      } catch (error) {
        log.warning('Error during getting the identities: $error');
        emit(state);
      }
    });

    on<FetchIdentityEvent>((event, emit) async {
      // Get from the API
      await Future.forEach(event.addresses, (address) async {
        try {
          final request = QueryIdentityRequest(account: address);
          final identity = await _indexerService.getIdentity(request);
          final indexerIdentity = IndexerIdentity(
            identity.accountNumber,
            identity.blockchain,
            identity.name,
          );
          await _identityStore.save(indexerIdentity, indexerIdentity.hiveId);
        } catch (_) {
          // Ignore bad API responses
          return;
        }
      });
    });

    on<RemoveAllEvent>((event, emit) async {
      await _identityStore.clear();
    });
  }
  final IndexerIdentityStore _identityStore;
  final NftIndexerService _indexerService;

  static const localIdentityCacheDuration = Duration(days: 1);

  Future<void> clear() async {
    await _identityStore.clear();
  }
}
