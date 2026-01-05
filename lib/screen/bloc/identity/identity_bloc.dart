//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/identity.dart';
import 'package:autonomy_flutter/service/hive_store_service.dart';

part 'identity_state.dart';

class IndexerIdentityStore extends HiveStoreObjectServiceImpl<IndexerIdentity> {
  static const String _key = 'indexerIdentityStoreKey';

  @override
  Future<void> init(String key) async {
    await super.init(_key);
  }
}

class IdentityBloc extends AuBloc<IdentityEvent, IdentityState> {
  IdentityBloc() : super(IdentityState({})) {
    on<GetIdentityEvent>((event, emit) async {
      emit(IdentityState({}));
    });
  }
  static const localIdentityCacheDuration = Duration(days: 1);
}
