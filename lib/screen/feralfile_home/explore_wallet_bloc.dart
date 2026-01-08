//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:autonomy_flutter/util/log.dart';

abstract class ExploreWalletEvent {}

class LoadWalletCountEvent extends ExploreWalletEvent {}

class ExploreWalletState {
  ExploreWalletState({
    this.walletCount = 0,
    this.isLoading = false,
  });

  final int walletCount;
  final bool isLoading;

  ExploreWalletState copyWith({
    int? walletCount,
    bool? isLoading,
  }) =>
      ExploreWalletState(
        walletCount: walletCount ?? this.walletCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

class ExploreWalletBloc extends AuBloc<ExploreWalletEvent, ExploreWalletState> {
  final ChannelService _channelService;

  ExploreWalletBloc(this._channelService) : super(ExploreWalletState()) {
    on<LoadWalletCountEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));

      try {
        // Only count wallets in keychain/blockstore without storing any data
        // iOS: Reads from iOS Keychain using SecItemCopyMatching
        // Android: Reads from Android Blockstore using retrieveBytes
        final mnemonicMap =
            await _channelService.exportMnemonicForAllPersonaUUIDs();

        final walletCount = mnemonicMap.length;
        log.info(
            '[ExploreWalletBloc] Found $walletCount wallet(s) in secure storage');

        emit(state.copyWith(
          walletCount: walletCount,
          isLoading: false,
        ));
      } catch (e, stackTrace) {
        log.severe(
            '[ExploreWalletBloc] Error counting wallets: $e', e, stackTrace);
        emit(state.copyWith(
          walletCount: 0,
          isLoading: false,
        ));
      }
    });
  }
}
