//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/iap_api.dart';
import 'package:autonomy_flutter/gateway/user_api.dart';
import 'package:autonomy_flutter/model/jwt.dart';
import 'package:autonomy_flutter/screen/bloc/artist_artwork_display_settings/artist_artwork_display_setting_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/hive_store_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/passkey_service.dart';
import 'package:autonomy_flutter/service/remote_config_service.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AuthService {
  final IAPApi _authApi;
  final UserApi _userApi;
  final ConfigurationService _configurationService;

  AuthService(
    this._authApi,
    this._userApi,
    this._configurationService,
  );

  final HiveStoreObjectService<String?> _authServiceStore =
      HiveStoreObjectServiceImpl<String?>()..init(_authServiceStoreKey);

  static const String _jwtKey = 'jwt';
  static const String _authServiceStoreKey = 'authServiceStoreKey';

  Future<void> init() async {
    await _authServiceStore.init(_authServiceStoreKey);
  }

  JWT? get _jwt {
    final jwtString = _authServiceStore.get(_jwtKey);
    if (jwtString == null || jwtString.isEmpty) {
      return null;
    }
    final jwtJson = Map<String, dynamic>.from(json.decode(jwtString) as Map);
    return JWT.fromJson(jwtJson);
  }

  // setter for jwt
  Future<void> _setJwt(JWT? jwt) async {
    await _authServiceStore.save(
        jwt == null ? null : json.encode(jwt.toJson()), _jwtKey);
  }

  String? getUserId() {
    return _jwt?.userId;
  }

  bool isBetaTester() {
    if (kDebugMode) return true;
    try {
      final isBetaTesterFromLocalConfig =
          injector<ConfigurationService>().isBetaTester();
      if (isBetaTesterFromLocalConfig) {
        return true;
      }
      final betaTester = injector<RemoteConfigService>()
          .getConfig<List<dynamic>>(ConfigGroup.tester, ConfigKey.betaTester,
              <String>[]).cast<String>();
      return betaTester.contains(getUserId());
    } catch (e) {
      log.warning('Failed to get beta tester config: $e');
      return false;
    }
  }

  Future<void> reset() async {
    await setAuthToken(null);
  }

  Future<JWT> _refreshJWT({String? receiptData}) async {
    final refreshToken = _jwt?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw JwtException(message: 'refresh_token_empty'.tr());
    }
    final Map<String, dynamic> payload = {'refreshToken': refreshToken};
    if (receiptData != null) {
      // add the receipt data if available
      final String platform;
      if (Platform.isIOS) {
        platform = 'apple';
      } else {
        platform = 'google';
      }
      payload.addAll({
        'inAppReceipt': {'platform': platform, 'receipt_data': receiptData}
      });
    }
    final newJwt = await _userApi.refreshJWT(payload);
    return newJwt;
  }

  Future<JWT> refreshJWT({String? receiptData, bool shouldRetry = true}) async {
    JWT? refreshedJwt;
    try {
      final newJwt = await _refreshJWT(receiptData: receiptData);
      refreshedJwt = _jwt!.copyWith(
        jwtToken: newJwt.jwtToken,
        expireIn: newJwt.expireIn,
      );
    } catch (e) {
      unawaited(Sentry.captureException(
          'Failed to refresh JWT, request passkey again, error: $e'));
      if (shouldRetry) {
        refreshedJwt =
            await injector<NavigationService>().showRefreshJwtFailedDialog(
          onRetry: () async {
            final refreshJwt = await injector<PasskeyService>().requestJwt();
            return refreshJwt;
          },
        );
      }
    }
    if (refreshedJwt == null) {
      throw JwtException(message: 'jwt_refresh_failed'.tr());
    }
    await setAuthToken(refreshedJwt, receiptData: receiptData);
    return refreshedJwt;
  }

  void _refreshSubscriptionStatus(JWT? jwt, {String? receiptData}) {
    if (jwt?.isValid(withSubscription: true) ?? false) {
      log.info('jwt with valid subscription');
      unawaited(_configurationService
          .setIAPReceipt(receiptData ?? _configurationService.getIAPReceipt()));
      unawaited(_configurationService.setIAPJWT(jwt));
    } else {
      log.info('jwt with invalid subscription');
      unawaited(_configurationService.setIAPReceipt(null));
      unawaited(_configurationService.setIAPJWT(null));
    }
    injector<SubscriptionBloc>().add(GetSubscriptionEvent());
  }

  Future<void> setAuthToken(JWT? jwt, {String? receiptData}) async {
    await _setJwt(jwt);

    _refreshSubscriptionStatus(jwt, receiptData: receiptData);
  }

  Future<JWT?> getAuthToken({bool shouldRefresh = true}) async {
    if (_jwt == null) {
      return null;
    }
    if (shouldRefresh) {
      if (!_jwt!.isValid()) {
        await refreshJWT();
      }
    }
    return _jwt;
  }

  Future<bool> redeemGiftCode(String giftCode) async {
    final response = await _authApi.redeemGiftCode(giftCode);
    return response.ok == 1;
  }

  Future<void> registerReferralCode({required String referralCode}) async {
    final body = {'code': referralCode};
    await _authApi.registerReferralCode(body);
  }

  Future<void> linkArtist(String token) async {
    final res = await _authApi.linkArtist({'token': token});
    // after link artist, we need to refresh the jwt
    await refreshJWT();
  }

  bool isLinkArtist(List<String> addresses) {
    if (addresses.isEmpty) {
      return false;
    }
    final linkAddresses = _jwt?.linkAddresses ?? [];
    final isArtist =
        addresses.every((element) => linkAddresses.contains(element));
    return isArtist;
  }

  Future<dynamic> configureArtwork(
      List<String> assetIds, ArtistDisplaySetting artworkSetting) async {
    final body = {
      'assetIDs': assetIds,
      ...artworkSetting.toJson(),
    };

    final res = await _authApi.updateArtworkConfigurations(body);
    return res;
  }
}
