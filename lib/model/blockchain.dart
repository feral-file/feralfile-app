//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

enum Blockchain {
  ETHEREUM,
  TEZOS;

  static Blockchain fromChain(String value) {
    final chain = value.split(':')[0];
    switch (chain) {
      case "eip155":
        return Blockchain.ETHEREUM;
      case "tezos":
        return Blockchain.TEZOS;
      default:
        throw Exception('Invalid blockchain: $value');
    }
  }

  String get name {
    switch (this) {
      case Blockchain.ETHEREUM:
        return "Ethereum";
      case Blockchain.TEZOS:
        return "Tezos";
    }
  }
}
