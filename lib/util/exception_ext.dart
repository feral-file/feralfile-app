import 'package:flutter/services.dart';

extension ExceptionExt on Exception {
  bool get isDataLongerThanAllowed {
    if (this is PlatformException) {
      final e = this as PlatformException;
      return e.code == 'writeCharacteristic' &&
          e.message?.contains('data longer than allowed') == true;
    } else {
      return false;
    }
  }
}
