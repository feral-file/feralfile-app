//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/iap_api.dart';
import 'package:autonomy_flutter/model/jwt.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/hive_store_service.dart';
import 'package:autonomy_flutter/util/log.dart';

class AuthService {
  AuthService(
    this._authApi,
    this._configurationService,
  );
  final IAPApi _authApi;
  final ConfigurationService _configurationService;

  final HiveStoreObjectService<String?> _authServiceStore =
      HiveStoreObjectServiceImpl<String?>(key: _authServiceStoreKey);

  static const String _jwtKey = 'jwt';
  static const String _authServiceStoreKey = 'authServiceStoreKey';

  Future<void> init() async {
    await _authServiceStore.init();
    log.info('AuthService initialized');
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
    return true; // public for all users
  }

  Future<void> reset() async {
    await setAuthToken(null);
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
      if (!_jwt!.isValid()) {}
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


}
