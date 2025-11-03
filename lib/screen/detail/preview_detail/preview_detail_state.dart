//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_page.dart';

abstract class ArtworkPreviewDetailEvent {}

class ArtworkPreviewDetailGetAssetTokenEvent extends ArtworkPreviewDetailEvent {
  final ArtworkIdentity identity;
  final bool useIndexer;

  ArtworkPreviewDetailGetAssetTokenEvent(this.identity,
      {this.useIndexer = false});
}

class ArtworkFeedPreviewDetailGetAssetTokenEvent
    extends ArtworkPreviewDetailEvent {
  final AssetToken assetToken;

  ArtworkFeedPreviewDetailGetAssetTokenEvent(this.assetToken);
}

abstract class ArtworkPreviewDetailState {
  ArtworkPreviewDetailState();
}

class ArtworkPreviewDetailLoadingState extends ArtworkPreviewDetailState {
  ArtworkPreviewDetailLoadingState();
}

class ArtworkPreviewDetailLoadedState extends ArtworkPreviewDetailState {
  AssetToken? assetToken;
  String? overriddenHtml;

  ArtworkPreviewDetailLoadedState({this.assetToken, this.overriddenHtml});
}
