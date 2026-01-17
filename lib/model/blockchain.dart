//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

enum Blockchain {
  ETHEREUM('eip155:1'),
  TEZOS('tezos:mainnet');

  const Blockchain(this.chain);

  /// Chain identifier used in CAIP-2 (e.g. 'eip155', 'tezos').
  final String chain;

  static Blockchain fromChain(String value) {
    final chain = value;
    switch (chain) {
      case "eip155:1":
        return Blockchain.ETHEREUM;
      case "tezos:mainnet":
        return Blockchain.TEZOS;
      default:
        throw Exception('Invalid blockchain: $value');
    }
  }

  String get name {
    switch (this) {
      case Blockchain.ETHEREUM:
        return 'Ethereum';
      case Blockchain.TEZOS:
        return 'Tezos';
    }
  }

  static List<Blockchain> fromName(String value) {
    switch (value) {
      case 'Ethereum':
        return [Blockchain.ETHEREUM];
      case 'Tezos':
        return [Blockchain.TEZOS];
      default:
        return [];
    }
  }
}
