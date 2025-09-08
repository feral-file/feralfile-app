import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class SafeDio extends DioForNative {
  SafeDio([super.options]);

  bool _isForeground = true;
  bool _allowBackgroundRequests = false;

  void setForeground(bool value) {
    _isForeground = value;
  }

  /// Allow HTTP requests to be executed while app is in background.
  /// Default is false (block background requests).
  void setAllowBackgroundRequests(bool value) {
    _allowBackgroundRequests = value;
  }

  void _checkForeground() {
    if (!_isForeground && !_allowBackgroundRequests) {
      throw StateError('❌ HTTP request blocked: app is in background');
    }
  }

  @override
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    _checkForeground();
    return super.request<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}
