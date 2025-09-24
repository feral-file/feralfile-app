//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/ff_artwork.dart';
import 'package:autonomy_flutter/model/ff_exhibition.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/nft_collection/models/provenance.dart';

abstract class ArtworkDetailEvent {}

class ArtworkDetailGetInfoEvent extends ArtworkDetailEvent {
  ArtworkDetailGetInfoEvent(this.identity,
      {this.useIndexer = false, this.withArtwork = false});

  final ArtworkIdentity identity;
  final bool withArtwork;
  final bool useIndexer;
}

class ArtworkDetailState {
  ArtworkDetailState({
    this.assetToken,
    this.owners = const {},
    this.artwork,
    this.exhibition,
  });

  final AssetToken? assetToken;
  final Map<String, int> owners;
  final Artwork? artwork;
  final Exhibition? exhibition;

  //copyWith
  ArtworkDetailState copyWith({
    AssetToken? assetToken,
    Map<String, int>? owners,
    Artwork? artwork,
    Exhibition? exhibition,
  }) =>
      ArtworkDetailState(
        assetToken: assetToken ?? this.assetToken,
        owners: owners ?? this.owners,
        artwork: artwork ?? this.artwork,
        exhibition: exhibition ?? this.exhibition,
      );
}
