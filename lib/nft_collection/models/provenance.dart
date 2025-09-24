//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

class Provenance {
  Provenance({
    required this.id,
    required this.type,
    required this.blockchain,
    required this.txID,
    required this.owner,
    required this.timestamp,
    required this.txURL,
    required this.tokenID,
    this.blockNumber,
  });

  factory Provenance.fromJson(
    Map<String, dynamic> json,
    String tokenID,
    int index,
  ) =>
      Provenance(
        id: '$tokenID-$index',
        type: json['type'] as String,
        blockchain: json['blockchain'] as String,
        txID: json['txID'] as String,
        owner: json['owner'] as String,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime(1970),
        txURL: (json['txURL'] as String?) ?? '',
        tokenID: tokenID,
        blockNumber: json['blockNumber'] as int?,
      );
  String id;
  String txID;
  String type;
  String blockchain;
  String owner;
  DateTime timestamp;
  String txURL;
  String tokenID;
  int? blockNumber;
}
