//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/customer_support_api.dart';
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/network_issue_manager.dart';
import 'package:autonomy_flutter/util/error_handler.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/exception_ext.dart';
import 'package:autonomy_flutter/util/int_ext.dart';
import 'package:autonomy_flutter/util/isolated_util.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:web3dart/crypto.dart';

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor();

  static final List<String> _skipLogPaths = [
    Environment.pubdocURL,
    Environment.remoteConfigURL,
    '${Environment.feralFileAPIURL}/api/exhibitions',
    '${Environment.feralFileAPIURL}/api/artworks',
  ];

  static String errorLogPrefix = 'Respond error:';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final curl = cURLRepresentation(err.requestOptions);
    apiLog
      ..info('API Request: $curl')
      ..warning('$errorLogPrefix ${err.response}');
    return handler.next(err);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    handler.next(response);
    await writeAPILog(response);
  }

  Future<void> writeAPILog(Response<dynamic> response) async {
    final apiPath =
        response.requestOptions.baseUrl + response.requestOptions.path;
    final skipLog = _skipLogPaths.any(apiPath.contains);
    if (skipLog) {
      return;
    }
    final shortCurlLog = await IsolatedUtil().shouldShortCurlLog(apiPath);
    if (shortCurlLog) {
      final request = response.requestOptions;
      apiLog.fine(
        'API Request: ${request.method} ${request.uri} ${request.data}',
      );
    } else {
      final curl = cURLRepresentation(response.requestOptions);
      apiLog.fine('API Request: $curl');
    }

    final shortAPIResponseLog =
        await IsolatedUtil().shouldShortAPIResponseLog(apiPath);
    if (shortAPIResponseLog) {
      apiLog.info('API Response Status: ${response.statusCode}');
    } else {
      final message = response.toString();
      apiLog.fine('API Response: $message');
    }

    final headers = response.headers.map;

    final cfRay = headers['cf-ray'];
    if (cfRay != null && cfRay.isNotEmpty) {
      apiLog.info('CF-Ray: ${cfRay.join(', ')}');
    }
  }

  String cURLRepresentation(RequestOptions options) {
    final components = <String>[r'$ curl -i'];
    if (options.method.toUpperCase() == 'GET') {
      components.add('-X ${options.method}');
    }

    options.headers.forEach((k, v) {
      if (k != 'Cookie') {
        components.add('-H "$k: $v"');
      }
    });

    try {
      var data = json.encode(options.data);
      data = data.replaceAll('"', r'\"');
      components.add('-d "$data"');
    } catch (err) {
      //ignore
    }

    components.add('"${options.uri}"');

    return components.join('\\\n\t');
  }
}

class SentryInterceptor extends InterceptorsWrapper {
  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = <String, dynamic>{
      'url': response.requestOptions.uri.toString(),
      'method': response.requestOptions.method,
      'status_code': response.statusCode,
    };
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          type: 'http',
          category: 'http',
          data: data,
        ),
      ),
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          type: 'http',
          category: 'http',
          level: SentryLevel.error,
          data: {
            'url': err.requestOptions.uri.toString(),
            'method': err.requestOptions.method,
            'status_code': err.response?.statusCode ?? 'NA',
            'reason': err.type.name,
          },
          message: err.message,
        ),
      ),
    );
    super.onError(err, handler);
  }
}

class AutonomyAuthInterceptor extends Interceptor {
  AutonomyAuthInterceptor();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final jwt = await injector<AuthService>().getAuthToken();
    if (jwt == null) {
      unawaited(Sentry.captureMessage('JWT is null'));
      log.info('JWT is null when calling ${options.uri}');
      throw JwtException(message: 'can_not_authenticate_desc'.tr());
    }

    options.headers['Authorization'] = 'Bearer ${jwt.jwtToken}';

    return handler.next(options);
  }
}

class CustomerSupportInterceptor extends Interceptor {
  CustomerSupportInterceptor();

  final _configurationService = injector<ConfigurationService>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isIgnoreHeaderApi = options.path == CustomerSupportApi.issuesPath;

    if (isIgnoreHeaderApi) {
      // do nothing get list issues, create issue: add header at api level
    } else {
      final pathElements = options.path.split('/');
      final anonymousIssueIds =
          injector<ConfigurationService>().getAnonymousIssueIds();
      if (pathElements.any(anonymousIssueIds.contains)) {
        // get issue details, add header
        options.headers[CustomerSupportApi.apiKeyHeader] =
            Environment.supportApiKey;
        options.headers[CustomerSupportApi.deviceIdHeader] =
            _configurationService.getAnonymousDeviceId();
      } else {
        final jwt = await injector<AuthService>().getAuthToken();
        // other api, add jwt
        if (jwt != null) {
          options.headers['Authorization'] = 'Bearer ${jwt.jwtToken}';
        } else {
          unawaited(Sentry.captureMessage('JWT is null'));
          throw JwtException(message: 'can_not_authenticate_desc'.tr());
        }
      }
    }

    return handler.next(options);
  }
}

class MetricsInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.headers['x-api-key'] == null) {
      options.headers['x-api-key'] = Environment.metricSecretKey;
    }
    handler.next(options);
  }
}

class FeralfileAuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.headers['X-Api-Signature'] == null &&
        options.method.toUpperCase() == 'POST') {
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final canonicalString = List<String>.of([
        options.uri.toString(),
        json.encode(options.data),
        timestamp,
      ]).join('|');
      final hmacSha256 =
          Hmac(sha256, utf8.encode(Environment.feralFileSecretKey));
      final digest = hmacSha256.convert(utf8.encode(canonicalString));
      final sig = bytesToHex(digest.bytes);
      options.headers['X-Api-Signature'] = 't=$timestamp,s=$sig';
    }
    handler.next(options);
  }
}

class FeralfileErrorHandlerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var exp = err;
    try {
      final errorBody = err.response?.data as Map<String, dynamic>;
      exp = err.copyWith(
        error: FeralfileError.fromJson(
          (errorBody['error'] as Map).typeCast<String, dynamic>(),
        ),
      );
    } catch (e) {
      log.info(
        '[FeralfileErrorHandlerInterceptor] Can not parse . ${err.response?.data}',
      );
    } finally {
      handler.next(exp);
    }
  }
}

class HmacAuthInterceptor extends Interceptor {
  HmacAuthInterceptor(this.secretKey);

  final String secretKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.headers['X-Api-Signature'] == null) {
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      var body = '';
      if (options.data is FormData || options.method.toUpperCase() == 'GET') {
        body = '';
      } else {
        body = bytesToHex(
          sha256
              .convert(
                options.data != null
                    ? utf8.encode(json.encode(options.data))
                    : [],
              )
              .bytes,
        );
      }
      final canonicalString = List<String>.of([
        options.path.split('?').first,
        body,
        timestamp,
      ]).join('|');
      final hmacSha256 = Hmac(sha256, utf8.encode(secretKey));
      final digest = hmacSha256.convert(utf8.encode(canonicalString));
      final sig = bytesToHex(digest.bytes);
      options.headers['X-Api-Signature'] = sig;
      options.headers['X-Api-Timestamp'] = timestamp;
    }
    handler.next(options);
  }
}

class ConnectingExceptionInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.isNetworkIssue) {
      Sentry.captureException(
        '[ConnectingExceptionInterceptor] Network issue detected: ${err.message}',
        stackTrace: StackTrace.current,
      );
      log.warning('ConnectingExceptionInterceptor timeout');
      unawaited(injector<NetworkIssueManager>().showNetworkIssueWarning());
      return;
    }
    if (err.type == DioExceptionType.receiveTimeout) {
      log.warning('ConnectingExceptionInterceptor receiveTimeout');
      unawaited(injector<NetworkIssueManager>().showReceiveTimeoutWarning());
      return;
    }
    handler.next(err);
  }
}

class TVKeyInterceptor extends Interceptor {
  TVKeyInterceptor(this.tvKey);

  final String tvKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['API-KEY'] = tvKey;
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    var exp = err;
    try {
      final errorBody = err.response?.data as Map<String, dynamic>;
      exp = err.copyWith(
        error: FeralfileError.fromJson(
          (errorBody['error'] as Map).typeCast<String, dynamic>(),
        ),
      );
    } catch (e) {
      log.info('[TVKeyInterceptor] Can not parse . ${err.response?.data}');
      unawaited(
        showErrorDialogFromException(
          ErrorBindingException(
            message: 'tv_error_binding_message'.tr(),
            originalException: err,
          ),
        ),
      );
    } finally {
      handler.next(exp);
    }
  }
}

class MobileControllerAuthInterceptor extends Interceptor {
  MobileControllerAuthInterceptor(this.apiKey);

  final String apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-API-KEY'] = apiKey;
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log.info(
      '[MobileControllerAuthInterceptor]Error: ${err.message} ',
    );
    handler.next(err);
  }
}

// log how long the request takes
class MeiliSearchInterceptor extends Interceptor {
  static Map<String, int> _requestTimes = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _requestTimes[options.uri.toString()] =
        DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    final requestTime = _requestTimes[response.requestOptions.uri.toString()];
    if (requestTime != null) {
      log.info(
          '[MeiliSearchInterceptor] Request time: ${DateTime.now().millisecondsSinceEpoch - requestTime} ms');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    log.info('[MeiliSearchInterceptor] Error: ${err.message}');
    handler.next(err);
  }
}
