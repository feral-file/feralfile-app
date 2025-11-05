//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/get_list_tokens.dart';
import 'package:autonomy_flutter/nft_collection/services/tokens_service.dart';
import 'package:autonomy_flutter/screen/detail/artwork_detail_state.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry/sentry.dart';

class ArtworkDetailBloc extends AuBloc<ArtworkDetailEvent, ArtworkDetailState> {
  final nftTokensService = injector<NftTokensService>();
  final database = injector<IndexerDatabaseAbstract>();
  final indexerService = injector<NftIndexerService>();

  ArtworkDetailBloc() : super(ArtworkDetailState()) {
    on<ArtworkDetailGetInfoEvent>((event, emit) async {
      if (event.useIndexer) {
        final token = await indexerService.getTokenByCid(
          QueryGetTokenByCidRequest(cid: event.identity.cid),
        );

        if (token != null) {
          emit(
            ArtworkDetailState(
              assetToken: token,
            ),
          );
        }
        return;
      } else {
        final assetToken = await database.findTokenByCid(
          event.identity.cid,
        );
        emit(
          ArtworkDetailState(
            assetToken: assetToken,
          ),
        );
        await _indexHistory(event.identity.cid);
      }
    });
  }

  Future<void> _indexHistory(String cid) async {
    try {
      // await indexerService.indexTokenHistory(cid);
    } catch (e) {
      log.info('index history error: $e');
      unawaited(
        Sentry.captureException(
          '[ArtworkDetailBloc] index history error: $e',
        ),
      );
    }
  }
}
