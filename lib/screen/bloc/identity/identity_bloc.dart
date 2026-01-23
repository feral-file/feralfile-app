//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/graphql/model/identity.dart';
import 'package:autonomy_flutter/nft_collection/services/indexer_service.dart';
import 'package:autonomy_flutter/util/log.dart';

part 'identity_state.dart';

class IdentityBloc extends AuBloc<IdentityEvent, IdentityState> {
  IdentityBloc(this._indexerService) : super(IdentityState({})) {
    on<GetIdentityEvent>((event, emit) async {});

    on<FetchIdentityEvent>((event, emit) async {});

    on<RemoveAllEvent>((event, emit) async {});
  }
  final NftIndexerService _indexerService;

  static const localIdentityCacheDuration = Duration(days: 1);
}
