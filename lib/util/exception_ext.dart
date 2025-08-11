import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';

extension ExceptionExt on Exception {
  bool get isNetworkIssue {
    if (this is DioException) {
      final e = this as DioException;
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.error is SocketException;
    }

    if (this is ClientException) {
      return true;
    }

    return false;
  }

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
