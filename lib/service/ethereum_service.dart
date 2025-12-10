//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

const double gWeiFactor = 1000000000;

abstract class EthereumService {
  Future<String> getFeralFileTokenMetadata(
    EthereumAddress contract,
    Uint8List data,
  );
}

class EthereumServiceImpl extends EthereumService {
  EthereumServiceImpl(
    this._web3Client,
  );

  final Web3Client _web3Client;

  @override
  Future<String> getFeralFileTokenMetadata(
    EthereumAddress contract,
    Uint8List data,
  ) async {
    final metadata = await _web3Client.callRaw(contract: contract, data: data);

    final outputs = <FunctionParameter<String>>[
      const FunctionParameter('string', StringType()),
    ];

    final tuple = TupleType(outputs.map((p) => p.type).toList());
    final buffer = hexToBytes(metadata).buffer;

    final parsedData = tuple.decode(buffer, 0);
    return parsedData.data.isNotEmpty ? parsedData.data.first as String : '';
  }
}
