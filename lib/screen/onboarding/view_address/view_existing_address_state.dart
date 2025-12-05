import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/exception.dart';

abstract class ViewExistingAddressEvent {}

class AddressChangeEvent extends ViewExistingAddressEvent {
  final String address;

  AddressChangeEvent(this.address);
}

class AddConnectionEvent extends ViewExistingAddressEvent {
  AddConnectionEvent();
}

class ViewExistingAddressState {
  final String address;
  final bool isValid;
  final bool isError;
  final String? domain;
  final CryptoType? type;
  final AddAddressException? exception;
  final bool isAddConnectionLoading;

  // constructor
  ViewExistingAddressState({
    this.address = '',
    this.isValid = false,
    this.isError = false,
    this.domain,
    this.type,
    this.exception,
    this.isAddConnectionLoading = false,
  });

  // copyWith
  ViewExistingAddressState copyWith({
    String? address,
    bool? isValid,
    bool? isError,
    String? domain,
    CryptoType? type,
    AddAddressException? exception,
    bool? isAddConnectionLoading,
  }) =>
      ViewExistingAddressState(
        address: address ?? this.address,
        isValid: isValid ?? this.isValid,
        isError: isError ?? this.isError,
        domain: domain ?? this.domain,
        type: type ?? this.type,
        exception:
            exception ?? (isError ?? this.isError ? this.exception : null),
        isAddConnectionLoading:
            isAddConnectionLoading ?? this.isAddConnectionLoading,
      );
}

class ViewExistingAddressSuccessState extends ViewExistingAddressState {
  ViewExistingAddressSuccessState(
    ViewExistingAddressState state,
    this.walletAddress,
  ) : super(
          address: state.address,
          isValid: state.isValid,
          isError: state.isError,
          domain: state.domain,
          type: state.type,
          exception: state.exception,
        );

  WalletAddress walletAddress;
}
