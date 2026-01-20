//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/nft_collection/services/drift_database_service.dart';
import 'package:autonomy_flutter/screen/mobile_controller/extensions/dp1_call_ext.dart';
import 'package:autonomy_flutter/screen/mobile_controller/models/dp1_call.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/index/view/playlists/bloc/playlists_bloc.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:drift/drift.dart';
import 'package:sentry/sentry.dart';

/// Service to bootstrap Drift database on app start
class DriftBootstrapService {
  DriftBootstrapService(this._db);

  static String get myCollectionChannelId => 'my_collection';

  final PlaylistDatabase _db;
  bool _hasBootstrapped = false;

  /// Bootstrap Drift database on first run
  Future<void> bootstrapIfNeeded() async {
    if (_hasBootstrapped) {
      return;
    }

    try {
      // Check if my_collection channel exists
      final myCollection = await _db.getChannelById('my_collection');
      if (myCollection != null) {
        log.info('[DriftBootstrapService] Database already bootstrapped');
        _hasBootstrapped = true;
        return;
      }

      log.info('[DriftBootstrapService] Starting bootstrap');

      // 1. Create 'my_collection' virtual channel
      await _createMyCollectionChannel();

      // 2. Create address playlists from stored addresses
      await _createAddressPlaylists();

      _hasBootstrapped = true;
      log.info('[DriftBootstrapService] Bootstrap completed');
    } catch (e, st) {
      log.info('[DriftBootstrapService] Error during bootstrap: $e');
      unawaited(Sentry.captureEvent(SentryEvent(
        message: SentryMessage('Error during bootstrap: $e'),
        level: SentryLevel.error,
      )));
    }
  }

  Future<void> _createMyCollectionChannel() async {
    try {
      final myCollectionChannel = ChannelsCompanion.insert(
        id: myCollectionChannelId,
        type: DriftChannelKind.localVirtual.value, // local_virtual
        title: 'My Collection',
        createdAtUs: DateTime.now().microsecondsSinceEpoch,
        updatedAtUs: DateTime.now().microsecondsSinceEpoch,
        baseUrl: const Value(null),
        slug: const Value('my-collection'),
        curator: const Value(null),
        summary: const Value('Your personal collection'),
        coverImageUri: const Value(null),
        sortOrder: const Value(0),
      );

      await _db.upsertChannel(myCollectionChannel);
      log.info('[DriftBootstrapService] Created my_collection channel');
    } catch (e, st) {
      log.info(
        '[DriftBootstrapService] Error creating my_collection channel: $e',
      );
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  Future<void> _createAddressPlaylists() async {
    try {
      final addressService = injector<AddressService>();
      final addresses = addressService.getAllAddresses(isHidden: false);

      final addressInDrift = await addressService.getAllAddressesFromDrift();

      final newAddresses = addresses
          .where((address) => !addressInDrift.contains(address))
          .toList();

      if (newAddresses.isEmpty) {
        log.info(
          '[DriftBootstrapService] No addresses to create playlists for',
        );
        return;
      }

      final playlistCompanions = <PlaylistsCompanion>[];
      for (final address in newAddresses) {
        final walletAddress = addressService.getWalletAddress(address);
        if (walletAddress == null) {
          continue;
        }
        final playlistId = DP1CallExtension.generatePlaylistId(address);
        final playlistTitle = walletAddress.name.maskIfNeeded();
        final chain = walletAddress.cryptoType.name;

        final dynamicQueriesParams = DynamicQueryParams(owners: [address]);
        final dynamicQuery = DynamicQuery(
            endpoint: '${Environment.indexerURL}/graphql',
            params: dynamicQueriesParams);

        playlistCompanions.add(
          PlaylistsCompanion.insert(
            id: playlistId,
            channelId: Value(myCollectionChannelId),
            type: DriftPlaylistKind.address.value, // address_playlist
            title: playlistTitle,
            createdAtUs: walletAddress.createdAt.microsecondsSinceEpoch,
            updatedAtUs: DateTime.now().microsecondsSinceEpoch,
            signaturesJson: '[]', // No signatures for address playlists
            ownerAddress: Value(address),
            ownerChain: Value(chain),
            sortMode: DriftPlaylistSortMode.provenance.value, // provenance
            itemCount: const Value(0),
            baseUrl: const Value(null),
            dpVersion: const Value(null),
            slug: const Value(null),
            defaultsJson: const Value(null),
            dynamicQueriesJson: Value(json.encode(dynamicQuery.toJson())),
          ),
        );
      }

      await _db.upsertPlaylists(playlistCompanions);
      log.info(
        '[DriftBootstrapService] Created ${playlistCompanions.length} address playlists',
      );
    } catch (e, st) {
      log.info('[DriftBootstrapService] Error creating address playlists: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }
}
