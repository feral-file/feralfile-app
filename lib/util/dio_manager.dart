//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/model/safe_dio.dart';
import 'package:autonomy_flutter/util/dio_exception_ext.dart';
import 'package:autonomy_flutter/util/dio_interceptors.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

/// A simple manager to create, cache, and manage multiple configured Dio instances.
///
/// This manager reuses Dio instances by a cache key derived from the client type
/// and the provided `BaseOptions` (currently `baseUrl`). Use `remove` or `clear`
/// to dispose existing instances when you need to refresh configuration.
class DioManager {
  DioManager._internal() {
    // Listen to app foreground/background changes and propagate to all Dio
    try {
      _fgbgSubscription = FGBGEvents.instance.stream.listen((event) {
        if (event == FGBGType.foreground) {
          markAppForeground();
          log.info('[DioManager] App to foreground: adapters reset');
        } else if (event == FGBGType.background) {
          markAppBackground();
          resetHttpAdapters();
          log.info('[DioManager] App to background');
        }
      });
    } catch (_) {
      // ignore if FGBGEvents not available in current platform context
    }
  }

  static final DioManager _instance = DioManager._internal();

  /// Get the singleton instance
  factory DioManager() => _instance;

  final Map<String, Dio> _cache = {};
  // ignore: unused_field
  StreamSubscription<FGBGType>? _fgbgSubscription;

  /// Close and reset http adapters of all cached Dio instances.
  void resetHttpAdapters({bool force = true}) {
    for (final dio in _cache.values) {
      try {
        dio.httpClientAdapter.close(force: force);
        dio.httpClientAdapter = IOHttpClientAdapter();
      } catch (_) {
        // ignore adapter close issues
      }
    }
  }

  /// Static helper to reset adapters on the singleton instance.
  static void resetAllHttpAdapters({bool force = true}) {
    _instance.resetHttpAdapters(force: force);
  }

  /// Set foreground/background state for all cached Dio instances (SafeDio only).
  void setForegroundForAll(bool isForeground) {
    for (final dio in _cache.values) {
      if (dio is SafeDio) {
        dio.setForeground(isForeground);
      }
    }
  }

  /// Static helper to set foreground/background on the singleton instance.
  static void setAllForeground(bool isForeground) {
    _instance.setForegroundForAll(isForeground);
  }

  /// Convenience wrappers
  static void markAppForeground() => setAllForeground(true);
  static void markAppBackground() => setAllForeground(false);

  /// Create or get a base-configured Dio (no extra auth interceptors).
  Dio base(BaseOptions options) => _getOrCreate(
        _key(Uuid().v1(), options),
        () => _createBaseDio(options),
      );

  /// Create or get a FeralFile-configured Dio.
  Dio feralFile(BaseOptions options) => _getOrCreate(
        _key('feralFile', options),
        () {
          final dio = _createBaseDio(options);
          dio.interceptors.add(FeralfileAuthInterceptor());
          dio.interceptors.add(FeralfileErrorHandlerInterceptor());
          return dio;
        },
      );

  /// Create or get a Customer Support-configured Dio.
  Dio customerSupport(BaseOptions options) => _getOrCreate(
        _key('customerSupport', options),
        () {
          final dio = _createBaseDio(options);
          dio.interceptors.add(CustomerSupportInterceptor());
          return dio;
        },
      );

  /// Create or get a TV Cast-configured Dio.
  Dio tvCast(BaseOptions options) => _getOrCreate(
        _key('tvCast', options),
        () {
          final dio = _createBaseDio(options);
          dio.interceptors.add(TVKeyInterceptor(Environment.tvKey));
          dio.addSentry(
            failedRequestStatusCodes: [SentryStatusCode.range(400, 599)],
          );
          return dio;
        },
      );

  /// Create or get a Mobile Controller-configured Dio.
  Dio mobileController(BaseOptions options) => _getOrCreate(
        _key('mobileController', options),
        () {
          final dio = _createBaseDio(options);
          dio.interceptors.add(MobileControllerAuthInterceptor(
              Environment.mobileControllerApiKey));
          dio.addSentry(
            failedRequestStatusCodes: [SentryStatusCode.range(400, 599)],
          );
          return dio;
        },
      );

  /// Create or get a Chat-configured Dio.
  Dio chat(BaseOptions options) => _getOrCreate(
        _key('chat', options),
        () {
          final dio = _createBaseDio(options);
          dio.interceptors
              .add(HmacAuthInterceptor(Environment.chatServerHmacKey));
          return dio;
        },
      );

  /// Remove and dispose a cached instance that matches the provided key parts.
  /// Use the same type and options used to create the client.
  bool remove(String type, BaseOptions options) {
    final key = _key(type, options);
    final dio = _cache.remove(key);
    if (dio != null) {
      dio.close(force: true);
      return true;
    }
    return false;
  }

  /// Dispose and clear all cached Dio instances.
  void clear() {
    for (final dio in _cache.values) {
      dio.close(force: true);
    }
    _cache.clear();
  }

  Dio _getOrCreate(String key, Dio Function() create) {
    final existing = _cache[key];
    if (existing != null) return existing;
    final dio = create();
    _cache[key] = dio;
    return dio;
  }

  String _key(String type, BaseOptions options) {
    // Key composition: type + baseUrl + key timeouts + followRedirects
    // Extend this when more dimensions are required.
    final baseUrl = options.baseUrl;
    final connectMs =
        (options.connectTimeout ?? const Duration(seconds: 10)).inMilliseconds;
    final receiveMs =
        (options.receiveTimeout ?? const Duration(seconds: 10)).inMilliseconds;
    final sendMs =
        (options.sendTimeout ?? const Duration(seconds: 10)).inMilliseconds;
    final follow = options.followRedirects;
    return '$type::$baseUrl|ct=$connectMs|rt=$receiveMs|st=$sendMs|fr=$follow';
  }

  Dio _createBaseDio(BaseOptions options) {
    final BaseOptions dioOptions = options.copyWith(
      followRedirects: true,
      connectTimeout: options.connectTimeout ?? const Duration(seconds: 10),
      receiveTimeout: options.receiveTimeout ?? const Duration(seconds: 10),
    );
    final dio = SafeDio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      validateCertificate: (cert, host, port) => true,
      createHttpClient: () =>
          HttpClient()..badCertificateCallback = (cert, host, port) => true,
    );

    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        logPrint: (message) {
          log.warning('[request retry] $message');
        },
        retryEvaluator: (error, attempt) {
          if (error.statusCode == 404) {
            return false;
          }
          if (error.statusCode >= 400 && error.statusCode < 500) {
            return false;
          }
          return true;
        },
        ignoreRetryEvaluatorExceptions: true,
        retryDelays: const [
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
        ],
      ),
    );

    dio.interceptors.add(LoggingInterceptor());
    dio.interceptors.add(ConnectingExceptionInterceptor());

    dio.options = dioOptions;
    dio.addSentry(failedRequestStatusCodes: [SentryStatusCode.range(500, 599)]);
    return dio;
  }
}
