//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:ui';

import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/util/log.dart';

abstract class AccountsEvent {}

class GetAccountsEvent extends AccountsEvent {}

class ChangeAccountOrderEvent extends AccountsEvent {
  ChangeAccountOrderEvent({required this.oldOrder, required this.newOrder});

  final int oldOrder;
  final int newOrder;
}

class FetchAllAddressesEvent extends AccountsEvent {}

class DeleteAddressEvent extends AccountsEvent {
  DeleteAddressEvent(this.address, {this.onSuccess, this.onError});

  final WalletAddress address;
  final FutureOr<void> Function()? onSuccess;
  final FutureOr<void> Function(Object error, StackTrace? stackTrace)? onError;
}

class GetAccountBalanceEvent extends AccountsEvent {
  GetAccountBalanceEvent(this.addresses);

  final List<String> addresses;
}

class AccountsState {
  AccountsState({
    this.addresses,
    this.addressBalances = const {},
  }) {
    log.info('Create AccountsState');
  }

  List<WalletAddress>? addresses;
  final Map<String, String> addressBalances;

  AccountsState copyWith({
    List<WalletAddress>? addresses,
    Map<String, String>? addressBalances,
  }) =>
      AccountsState(
        addresses: addresses ?? this.addresses,
        addressBalances: addressBalances ?? this.addressBalances,
      );
}

abstract class AccountBlocStateEvent {}

class FetchAllAddressesSuccessEvent extends AccountBlocStateEvent {
  FetchAllAddressesSuccessEvent(this.addresses);

  final List<String> addresses;
}
