//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:io';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/persona_wallet.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:autonomy_flutter/util/log.dart';

abstract class ExploreWalletEvent {}

class LoadPersonaWalletsEvent extends ExploreWalletEvent {}

class ExploreWalletState {
  ExploreWalletState({
    this.personaWallets = const [],
    this.isLoading = false,
    this.diagnosticInfo,
  });

  final List<PersonaWallet> personaWallets;
  final bool isLoading;
  final String? diagnosticInfo;

  ExploreWalletState copyWith({
    List<PersonaWallet>? personaWallets,
    bool? isLoading,
    String? diagnosticInfo,
  }) =>
      ExploreWalletState(
        personaWallets: personaWallets ?? this.personaWallets,
        isLoading: isLoading ?? this.isLoading,
        diagnosticInfo: diagnosticInfo ?? this.diagnosticInfo,
      );
}

class ExploreWalletBloc extends AuBloc<ExploreWalletEvent, ExploreWalletState> {
  final ChannelService _channelService;
  final Future<List<WalletAddress>> Function() _getAddresses;

  ExploreWalletBloc(this._channelService, this._getAddresses)
      : super(ExploreWalletState()) {
    on<LoadPersonaWalletsEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));

      try {
        // Get all personas with their mnemonics directly from keychain/blockstore
        // iOS: Reads from iOS Keychain using SecItemCopyMatching
        // Android: Reads from Android Blockstore using retrieveBytes
        // Returns: Map<PersonaUUID, [passphrase, ...mnemonic_words]>
        final mnemonicMap =
            await _channelService.exportMnemonicForAllPersonaUUIDs();

        log.info(
            '[ExploreWalletBloc] Fetched ${mnemonicMap.length} persona(s) from keychain/blockstore');
        log.info(
            '[ExploreWalletBloc] Persona UUIDs: ${mnemonicMap.keys.toList()}');

        // Note: Addresses are stored in a separate database and cannot be reliably
        // associated with specific personas (WalletAddress has no personaUUID field).
        // We fetch them only for diagnostic purposes.
        List<WalletAddress> allAddresses = [];
        try {
          allAddresses = await _getAddresses();
          log.info(
              '[ExploreWalletBloc] Found ${allAddresses.length} address(es) in database');
          if (allAddresses.isNotEmpty) {
            log.info(
                '[ExploreWalletBloc] Sample address: ${allAddresses.first.address}');
          }
        } catch (e) {
          log.info(
              '[ExploreWalletBloc] Could not fetch addresses from database: $e');
        }

        // Create PersonaWallet objects from keychain data
        final personaWallets = <PersonaWallet>[];

        for (final entry in mnemonicMap.entries) {
          final uuid = entry.key;
          final mnemonicData = entry.value;

          log.info(
              '[ExploreWalletBloc] Processing persona: $uuid with ${mnemonicData.length} words');

          // Data format: [passphrase, word1, word2, ..., wordN]
          // First element is passphrase (empty string if no passphrase)
          final passphrase =
              mnemonicData.isNotEmpty && mnemonicData.first.isNotEmpty
                  ? mnemonicData.first
                  : null;
          final mnemonic =
              mnemonicData.length > 1 ? mnemonicData.sublist(1) : mnemonicData;

          // Note: We cannot reliably associate addresses with personas
          // because WalletAddress model has no personaUUID field.
          // Setting firstAddress to null for now.
          personaWallets.add(
            PersonaWallet(
              uuid: uuid,
              mnemonic: mnemonic,
              passphrase: passphrase,
              firstAddress: null, // Cannot associate addresses with personas
            ),
          );
        }

        log.info(
            '[ExploreWalletBloc] Created ${personaWallets.length} PersonaWallet objects');

        // Create diagnostic info for UI
        final diagnosticInfo = StringBuffer();
        final platform = Platform.isIOS ? 'iOS Keychain' : 'Android Blockstore';
        diagnosticInfo.writeln(
            'Full wallets in keychain/blockstore: ${mnemonicMap.length}');
        diagnosticInfo.writeln('\n(Reading directly from $platform)');

        if (mnemonicMap.isNotEmpty) {
          diagnosticInfo.writeln('\nPersona UUIDs:');
          for (final uuid in mnemonicMap.keys) {
            diagnosticInfo.writeln('• $uuid');
          }
        } else {
          diagnosticInfo.writeln('\n❌ No full wallets found');
          diagnosticInfo.writeln('\nThis means:');
          diagnosticInfo
              .writeln('• No wallets with recovery phrases in secure storage');
          diagnosticInfo.writeln('• Keychain/Blockstore is empty or locked');
          diagnosticInfo
              .writeln('• You may need to create or restore a wallet');
        }

        diagnosticInfo
            .writeln('\n---\nAddresses in database: ${allAddresses.length}');
        if (allAddresses.isNotEmpty) {
          diagnosticInfo.writeln('\n(Note: From DB, not keychain)');
          for (final addr in allAddresses.take(3)) {
            final preview = addr.address.length > 20
                ? '${addr.address.substring(0, 20)}...'
                : addr.address;
            diagnosticInfo.writeln('• $preview (${addr.cryptoType.name})');
          }
          if (allAddresses.length > 3) {
            diagnosticInfo.writeln('... and ${allAddresses.length - 3} more');
          }
        }

        emit(state.copyWith(
          personaWallets: personaWallets,
          isLoading: false,
          diagnosticInfo: diagnosticInfo.toString(),
        ));
      } catch (e, stackTrace) {
        log.severe('[ExploreWalletBloc] Error loading persona wallets: $e', e,
            stackTrace);

        // Create diagnostic info for error case
        final diagnosticInfo = StringBuffer();
        diagnosticInfo.writeln('Error loading wallets:');
        diagnosticInfo.writeln(e.toString());
        diagnosticInfo.writeln('\nThis might mean:');
        diagnosticInfo.writeln('• No wallets stored in keychain');
        diagnosticInfo.writeln('• Permission issue accessing keychain');
        diagnosticInfo.writeln('• Data corruption');

        emit(state.copyWith(
          isLoading: false,
          diagnosticInfo: diagnosticInfo.toString(),
        ));
      }
    });
  }
}
