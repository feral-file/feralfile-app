//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:dio/dio.dart';

/// OpenPanel SDK for tracking events and identifying users.
///
/// This SDK provides methods to interact with the OpenPanel API:
/// - Track events with custom properties
/// - Identify users with profile information
/// - Increment/decrement numeric properties
///
/// Documentation: https://openpanel.dev/docs/api/track
class OpenPanelSdk {
  OpenPanelSdk({
    required String clientId,
    required String clientSecret,
    String? baseUrl,
    String? clientIp,
    String? userAgent,
  })  : _clientId = clientId,
        _clientSecret = clientSecret,
        _baseUrl = baseUrl ?? 'https://api.openpanel.dev',
        _clientIp = clientIp,
        _userAgent = userAgent {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          'Content-Type': 'application/json',
          'openpanel-client-id': _clientId,
          'openpanel-client-secret': _clientSecret,
          if (_clientIp != null) 'x-client-ip': _clientIp,
          if (_userAgent != null) 'user-agent': _userAgent,
        },
      ),
    );
  }

  final String _clientId;
  final String _clientSecret;
  final String _baseUrl;
  final String? _clientIp;
  final String? _userAgent;
  late final Dio _dio;

  /// Track an event with optional properties.
  ///
  /// [name] is the event name (required).
  /// [properties] are optional custom properties to attach to the event.
  ///
  /// Throws [DioException] if the request fails.
  Future<void> track({
    required String name,
    Map<String, dynamic>? properties,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/track',
        data: {
          'type': 'track',
          'payload': {
            'name': name,
            if (properties != null) 'properties': properties,
          },
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Identify a user with profile information.
  ///
  /// [profileId] is the unique identifier for the user (required).
  /// [firstName], [lastName], [email] are optional user details.
  /// [properties] are optional custom properties to attach to the profile.
  ///
  /// Throws [DioException] if the request fails.
  Future<void> identify({
    required String profileId,
    String? firstName,
    String? lastName,
    String? email,
    Map<String, dynamic>? properties,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/track',
        data: {
          'type': 'identify',
          'payload': {
            'profileId': profileId,
            if (firstName != null) 'firstName': firstName,
            if (lastName != null) 'lastName': lastName,
            if (email != null) 'email': email,
            if (properties != null) 'properties': properties,
          },
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Increment a numeric property for a user profile.
  ///
  /// [profileId] is the unique identifier for the user (required).
  /// [property] is the name of the property to increment (required).
  /// [value] is the amount to increment by (defaults to 1).
  ///
  /// Throws [DioException] if the request fails.
  Future<void> increment({
    required String profileId,
    required String property,
    int value = 1,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/track',
        data: {
          'type': 'increment',
          'payload': {
            'profileId': profileId,
            'property': property,
            'value': value,
          },
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Decrement a numeric property for a user profile.
  ///
  /// [profileId] is the unique identifier for the user (required).
  /// [property] is the name of the property to decrement (required).
  /// [value] is the amount to decrement by (defaults to 1).
  ///
  /// Throws [DioException] if the request fails.
  Future<void> decrement({
    required String profileId,
    required String property,
    int value = 1,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/track',
        data: {
          'type': 'decrement',
          'payload': {
            'profileId': profileId,
            'property': property,
            'value': value,
          },
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Update client IP for geo location tracking.
  ///
  /// This will be included in subsequent requests as the `x-client-ip` header.
  void setClientIp(String? clientIp) {
    if (clientIp != null) {
      _dio.options.headers['x-client-ip'] = clientIp;
    } else {
      _dio.options.headers.remove('x-client-ip');
    }
  }

  /// Update user agent for device information tracking.
  ///
  /// This will be included in subsequent requests as the `user-agent` header.
  void setUserAgent(String? userAgent) {
    if (userAgent != null) {
      _dio.options.headers['user-agent'] = userAgent;
    } else {
      _dio.options.headers.remove('user-agent');
    }
  }

  /// Handle and format API errors.
  DioException _handleError(DioException error) {
    if (error.response != null) {
      final errorData = error.response?.data;

      // Try to extract error message from response
      String? errorMessage;
      if (errorData is Map<String, dynamic>) {
        errorMessage = errorData['error'] as String?;
      }

      return DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: errorMessage ?? error.message,
      );
    }
    return error;
  }

  /// Dispose resources.
  void dispose() {
    _dio.close();
  }
}
