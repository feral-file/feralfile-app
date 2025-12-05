//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: sort_constructors_first

import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/view/account_view.dart';
import 'package:sentry/sentry.dart';

class AccountsBloc extends AuBloc<AccountsEvent, AccountsState> {
  final AddressService _addressService;
  final AppDataManager _appDataManager;

  AccountsBloc(this._addressService, this._appDataManager)
      : super(AccountsState()) {
    on<GetAccountsEvent>((event, emit) async {
      final addresses = _appDataManager.addressStorageService.getAllAddresses();
      emit(
        state.copyWith(
          addresses: addresses,
        ),
      );
      add(GetAccountBalanceEvent(addresses.map((e) => e.address).toList()));
    });

    on<ChangeAccountOrderEvent>((event, emit) {
      var newOrder = event.newOrder;
      final oldOrder = event.oldOrder;
      if (oldOrder == newOrder ||
          state.addresses == null ||
          oldOrder >= state.addresses!.length ||
          newOrder > state.addresses!.length) {
        return;
      }

      if (oldOrder < newOrder) {
        newOrder -= 1;
      }
      final newAddresses = <WalletAddress>[...state.addresses!];
      final address = newAddresses.removeAt(oldOrder);
      newAddresses.insert(newOrder, address);
      emit(state.copyWith(addresses: newAddresses));
      _addressService.insertAddresses(newAddresses);
    });

    on<GetAccountBalanceEvent>((event, emit) async {
      final addressBalances = <String, String>{};
      for (final address in event.addresses) {
        try {
          final balance = await getNftBalance(address);
          addressBalances[address] = balance;
          emit(
            state.copyWith(
              addressBalances: Map.from(
                addressBalances
                  ..addAll(
                    state.addressBalances,
                  ),
              ),
            ),
          );
        } catch (e, s) {
          unawaited(
            Sentry.captureException(
              'Failed to get balance for $address: $e',
              stackTrace: s,
            ),
          );
        }
      }
    });

    on<FetchAllAddressesEvent>((event, emit) async {
      final addresses = _addressService.getAllWalletAddresses()
        ..removeWhere((e) => e.address.isEmpty);

      final newState = state.copyWith(
        addresses: addresses,
      );
      emit(newState);
    });

    on<DeleteAddressEvent>((event, emit) async {
      try {
        await _addressService.deleteAddress(event.address);
        final addresses = _addressService.getAllWalletAddresses();
        emit(state.copyWith(addresses: addresses));
        await event.onSuccess?.call();
      } catch (e, s) {
        await event.onError?.call(e, s);
      }
    });
  }
}
