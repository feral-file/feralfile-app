//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/domain_address_service.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Onboarding-specific bloc for adding a view-only address.
///
/// All validation and domain/address resolution is executed when
/// [OnboardingAddConnectionEvent] is dispatched.
abstract class OnboardingAddAddressEvent {}

class OnboardingAddConnectionEvent extends OnboardingAddAddressEvent {
  OnboardingAddConnectionEvent(this.address, this.isFromOnboarding);

  final String address;
  final bool isFromOnboarding;
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
    on<OnboardingAddConnectionEvent>(_onAddConnection);
  }

  Future<void> _onAddConnection(
    OnboardingAddConnectionEvent event,
    Emitter<OnboardingAddAddressState> emit,
  ) async {
    final text = event.address.trim();
    if (text.isEmpty) {
      emit(
        state.copyWith(
          error: Exception('Address is empty'),
          isSubmitting: false,
        ),
      );
      return;
    }

    String? address;
    String? domain;

    emit(
      state.copyWith(
        error: null,
        isSubmitting: true,
      ),
    );

    try {
      final addressInfo =
          await _domainAddressService.verifyAddressOrDomain(text);
      if (addressInfo == null) {
        emit(
          state.copyWith(
            error: AddAddressException(
              type: AddAddressExceptionType.invalidAddress,
            ),
            isSubmitting: false,
          ),
        );
        return;
      }
      address = addressInfo.address;
      domain = addressInfo.domain;
      final walletAddress = WalletAddress(
        address: address,
        name: domain ?? text,
        createdAt: DateTime.now(),
      );
      final connection = await _addressService.insertAddress(
        walletAddress,
        refreshPlaylist: !event.isFromOnboarding,
      );
      emit(OnboardingAddAddressSuccessState(connection));
    } on AddAddressException catch (e) {
      emit(
        state.copyWith(
          error: e,
          isSubmitting: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: AddAddressException(type: AddAddressExceptionType.other),
          isSubmitting: false,
        ),
      );
    }
  }

  final DomainAddressService _domainAddressService;
  final AddressService _addressService;
}
