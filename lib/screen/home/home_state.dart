//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/token.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';

abstract class HomeEvent {}

class CheckReviewAppEvent extends HomeEvent {}

class HomeState {
  HomeState({
    this.tokens,
    this.fetchTokenState = ActionState.notRequested,
  });

  List<AssetToken>? tokens;
  ActionState fetchTokenState;

  HomeState copyWith({
    List<AssetToken>? tokens,
    ActionState? fetchTokenState,
  }) {
    return HomeState(
      tokens: tokens ?? this.tokens,
      fetchTokenState: fetchTokenState ?? this.fetchTokenState,
    );
  }
}
