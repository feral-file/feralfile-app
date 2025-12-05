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
}
