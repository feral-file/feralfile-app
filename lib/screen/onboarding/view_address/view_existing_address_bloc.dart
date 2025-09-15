import 'dart:async';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/model/address.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address_state.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/domain_address_service.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/latest_async.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:bloc/bloc.dart';

class ViewExistingAddressBloc
    extends AuBloc<ViewExistingAddressEvent, ViewExistingAddressState> {
  final DomainAddressService _domainAddressService;
  final AddressService _addressService;
  final LatestAsync<Address?> _latestAsync = LatestAsync<Address?>();

  ViewExistingAddressBloc(
    this._domainAddressService,
    this._addressService,
  ) : super(ViewExistingAddressState()) {
    on<AddressChangeEvent>(_onAddressChanged);

    on<AddConnectionEvent>((event, emit) async {
      if (!isValid) {
        emit(
          state.copyWith(
            isError: true,
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          isAddConnectionLoading: true,
        ),
      );

      try {
        final walletAddress = WalletAddress(
          address: state.address,
          name: state.domain,
          createdAt: DateTime.now(),
        );
        final connection = await _addressService.insertAddress(
          walletAddress,
        );
        emit(ViewExistingAddressSuccessState(state, connection));
      } on LinkAddressException catch (e) {
        emit(
          state.copyWith(
            isError: true,
            exception: e,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(isError: true),
        );
      }
      emit(
        state.copyWith(
          isAddConnectionLoading: false,
        ),
      );
    });
  }

  bool get isValid =>
      state.isValid && state.address.isNotEmpty && state.type != null;

  @override
  Future<void> close() {
    _latestAsync.cancelInFlight();
    return super.close();
  }

  Future<Address?> _checkDomain(String text) async {
    return _domainAddressService.verifyAddressOrDomain(text);
  }

  Future<void> _onAddressChanged(
    AddressChangeEvent event,
    Emitter<ViewExistingAddressState> emit,
  ) async {
    final address = event.address.trim();

    // Emit initial state for address processing
    emit(
      state.copyWith(
        isError: false,
        isValid: false,
        address: address,
      ),
    );

    // Early exit if address is empty
    if (address.isEmpty) {
      return;
    }

    // Use LatestAsync to handle concurrent requests
    await _latestAsync.run(
      () => _checkDomain(address),
      onData: (domainInfo) {
        log.info('Domain info for ${event.address}: $domainInfo');

        if (domainInfo != null) {
          emit(
            state.copyWith(
              address: domainInfo.address,
              domain: domainInfo.domain,
              isValid: true,
              type: domainInfo.type,
              isError: false,
            ),
          );
        } else {
          emit(
            state.copyWith(
              address: address,
              isValid: false,
              isError: true, // Invalid address
            ),
          );
        }
      },
      onError: (error, stackTrace) {
        log.info('Error checking domain for ${event.address}: $error');
        emit(
          state.copyWith(
            address: address,
            isValid: false,
            isError: true,
          ),
        );
      },
    );
  }
}
