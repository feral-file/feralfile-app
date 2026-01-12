//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/playlist_database.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:drift/drift.dart';
import 'package:sentry/sentry.dart';

/// Service to bootstrap Drift database on app start
class DriftBootstrapService {
  DriftBootstrapService(this._db);

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
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  Future<void> _createMyCollectionChannel() async {
    try {
      final myCollectionChannel = ChannelsCompanion.insert(
        id: 'my_collection',
        type: 1, // local_virtual
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

      if (addresses.isEmpty) {
        log.info(
          '[DriftBootstrapService] No addresses to create playlists for',
        );
        return;
      }

      final playlistCompanions = <PlaylistsCompanion>[];
      for (final address in addresses) {
        final walletAddress = addressService.getWalletAddress(address);
        if (walletAddress == null) {
          continue;
        }

        final chain = walletAddress.cryptoType == CryptoType.ETH
            ? 'evm'
            : walletAddress.cryptoType == CryptoType.XTZ
                ? 'tezos'
                : 'other';
        final playlistId = 'addr:$chain:$address';
        final playlistTitle =
            walletAddress.name ?? 'Address ${address.substring(0, 8)}...';

        playlistCompanions.add(
          PlaylistsCompanion.insert(
            id: playlistId,
            channelId: const Value('my_collection'),
            type: 1, // address_playlist
            title: playlistTitle,
            createdAtUs: walletAddress.createdAt.microsecondsSinceEpoch,
            updatedAtUs: DateTime.now().microsecondsSinceEpoch,
            signaturesJson: '[]', // No signatures for address playlists
            ownerAddress: Value(address.toUpperCase()),
            ownerChain: Value(chain),
            sortMode: 1, // provenance
            itemCount: const Value(0),
            baseUrl: const Value(null),
            dpVersion: const Value(null),
            slug: const Value(null),
            defaultsJson: const Value(null),
            dynamicQueriesJson: const Value(null),
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
