enum AddAddressExceptionType {
  invalidAddress,
  alreadyAdded,
  other;

  String get message {
    switch (this) {
      case AddAddressExceptionType.invalidAddress:
        return 'Invalid address';
      case AddAddressExceptionType.alreadyAdded:
        return 'Address already added';
      case AddAddressExceptionType.other:
        return 'Other error';
    }
  }
}

class AddAddressException implements Exception {
  AddAddressException({
    required this.type,
  });
  final AddAddressExceptionType type;

  String get message => type.message;
}

class ErrorBindingException implements Exception {
  ErrorBindingException({
    required this.message,
    required this.originalException,
  });
  final String message;
  final Exception originalException;
}
