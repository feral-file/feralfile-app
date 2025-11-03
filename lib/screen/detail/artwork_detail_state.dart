//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';

abstract class ArtworkDetailEvent {}

class ArtworkDetailGetInfoEvent extends ArtworkDetailEvent {
  ArtworkDetailGetInfoEvent(this.identity, {this.useIndexer = false});

  final ArtworkIdentity identity;
  final bool useIndexer;
}

class ArtworkDetailState {
  ArtworkDetailState({
    this.assetToken,
    this.owners = const {},
  });

  final AssetToken? assetToken;
  final Map<String, int> owners;

  //copyWith
  ArtworkDetailState copyWith({
    AssetToken? assetToken,
    Map<String, int>? owners,
  }) =>
      ArtworkDetailState(
        assetToken: assetToken ?? this.assetToken,
        owners: owners ?? this.owners,
      );
}
