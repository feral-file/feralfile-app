//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';

class HiddenArtworksBloc extends AuBloc<HiddenArtworksEvent, List<AssetToken>> {
  HiddenArtworksBloc(this.appDataManager, this.database) : super([]) {
    on<HiddenArtworksEvent>((event, emit) async {
      final hiddenArtworks =
          appDataManager.appSettingsStorageService.hiddenTokenIDs;
      final tokens = await database.getTokensByCIDs(cids: hiddenArtworks)
        ..removeWhere((element) => !hiddenArtworks.contains(element.cid));
      emit(tokens);
    });
  }
  final AppDataManager appDataManager;
  final IndexerDatabaseAbstract database;
}

class HiddenArtworksEvent {}
