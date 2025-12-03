class LinkAddressException implements Exception {
  LinkAddressException({required this.message});
  final String message;
}

class ErrorBindingException implements Exception {
  ErrorBindingException({
    required this.message,
    required this.originalException,
  });
  final String message;
  final Exception originalException;
}
