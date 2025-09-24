//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/models/asset_token.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';

class HiddenArtworksBloc
    extends AuBloc<HiddenArtworksEvent, List<CompactedAssetToken>> {
  final ConfigurationService configurationService;
  final IndexerDatabaseAbstract database;

  HiddenArtworksBloc(this.configurationService, this.database) : super([]) {
    on<HiddenArtworksEvent>((event, emit) async {
      final hiddenArtworks =
          configurationService.getTempStorageHiddenTokenIDs();
      final assets =
          database.getAssetTokensByIndexIds(indexIds: hiddenArtworks);
      final compactedAssetToken =
          assets.map((e) => CompactedAssetToken.fromAssetToken(e)).toList();

      compactedAssetToken.removeWhere((element) =>
          !hiddenArtworks.contains(element.id) || element.balance == 0);
      emit(compactedAssetToken);
    });
  }
}

class HiddenArtworksEvent {}
