import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:dio/dio.dart';

extension DioExceptionExt on DioException {
  String get data => response?.data as String? ?? '';

  String get dataMessage {
    if (response?.data is Map) {
      return (response?.data as Map)['message'] as String? ?? '';
    }
    return '';
  }

  int get statusCode => response?.statusCode ?? 0;

  int? get ffErrorCode => response?.data['error']['code'] as int?;

  bool get isAlreadySetReferralCode {
    if (response?.data is Map) {
      return response!.statusCode == 400 &&
          (response!.data as Map)['error']?['code'] == 3002;
    }
    return false;
  }
}
