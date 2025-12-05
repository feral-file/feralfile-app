import 'dart:async';

extension CompleterExt<T> on Completer<T> {
  void safeComplete(T? value) {
    if (!isCompleted) {
      complete(value);
    }
  }

  void safeCompleteError(Object error, {StackTrace? stackTrace}) {
    if (!isCompleted) {
      completeError(error, stackTrace);
    }
  }
}
