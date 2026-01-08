//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

/// Represents a full wallet (persona) with recovery phrase
class PersonaWallet {
  PersonaWallet({
    required this.uuid,
    required this.mnemonic,
    this.passphrase,
    this.firstAddress,
  });

  final String uuid;
  final List<String> mnemonic;
  final String? passphrase;
  final String? firstAddress;

  String get displayName => 'Wallet ${uuid.substring(0, 8)}';
}

