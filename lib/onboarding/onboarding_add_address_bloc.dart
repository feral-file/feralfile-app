//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/address.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/domain_address_service.dart';
import 'package:autonomy_flutter/util/exception.dart';

/// Onboarding-specific bloc for adding a view-only address.
///
/// All validation and domain/address resolution is executed when
/// [OnboardingAddConnectionEvent] is dispatched.
abstract class OnboardingAddAddressEvent {}

class OnboardingAddConnectionEvent extends OnboardingAddAddressEvent {
  OnboardingAddConnectionEvent(this.address);

  final String address;
}

class OnboardingAddAddressState {
  const OnboardingAddAddressState({
    this.isSubmitting = false,
    this.error,
  });

  final bool isSubmitting;
  final Exception? error;

  OnboardingAddAddressState copyWith({
    bool? isSubmitting,
    Exception? error,
  }) {
    return OnboardingAddAddressState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

class OnboardingAddAddressSuccessState extends OnboardingAddAddressState {
  const OnboardingAddAddressSuccessState(this.walletAddress)
      : super(isSubmitting: false, error: null);

  final WalletAddress walletAddress;
}

class OnboardingAddAddressBloc
    extends AuBloc<OnboardingAddAddressEvent, OnboardingAddAddressState> {
  OnboardingAddAddressBloc(
    DomainAddressService domainAddressService,
    AddressService addressService,
  )   : _domainAddressService = domainAddressService,
        _addressService = addressService,
        super(const OnboardingAddAddressState()) {
    on<OnboardingAddConnectionEvent>((event, emit) async {
      final rawAddress = event.address.trim();
      if (rawAddress.isEmpty) {
        emit(
          state.copyWith(
            error: Exception('Address is empty'),
            isSubmitting: false,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          error: null,
          isSubmitting: true,
        ),
      );
      try {
        final domainInfo = await _checkDomain(rawAddress);

        if (domainInfo == null) {
          emit(
            state.copyWith(
              error: Exception('Invalid address'),
              isSubmitting: false,
            ),
          );
          return;
        }

        final walletAddress = WalletAddress(
          address: domainInfo.address,
          name: domainInfo.domain,
          createdAt: DateTime.now(),
        );
        final connection = await _addressService.insertAddress(
          walletAddress,
          refreshPlaylist: false,
        );
        emit(OnboardingAddAddressSuccessState(connection));
      } on LinkAddressException catch (e) {
        emit(
          state.copyWith(
            error: e,
            isSubmitting: false,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            error: e is Exception ? e : Exception(e.toString()),
            isSubmitting: false,
          ),
        );
      }
    });
  }

  final DomainAddressService _domainAddressService;
  final AddressService _addressService;

  Future<Address?> _checkDomain(String text) async {
    return _domainAddressService.verifyAddressOrDomain(text);
  }
}
