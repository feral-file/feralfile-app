//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/database/hive_storage_service.dart';
import 'package:autonomy_flutter/util/log.dart';

class SettingsStorageService extends HiveStorageService {
  SettingsStorageService(super.db, super.prefix);

  // App settings keys
  static const _keyIsAnalyticsEnabled = 'isAnalyticsEnabled';
  static const _keyDevicePasscodeEnabled = 'devicePasscodeEnabled';
  static const _keyNotificationEnabled = 'notificationEnabled';
  static const _keyBetaFeaturesEnabled = 'betaFeaturesEnabled';
  static const _keyExploreBarEnabled = 'exploreBarEnabled';
  static const _keyHiddenMainnetTokenIDs = 'hiddenMainnetTokenIDs';
  static const _keySelectedDeviceId = 'selectedDeviceId';

  // ========== Direct Access Methods (Single Source of Truth) ==========

  /// Analytics
  bool get isAnalyticsEnabled =>
      _getBool(_keyIsAnalyticsEnabled, defaultValue: true);

  Future<void> setAnalyticsEnabled(bool value) async {
    await _setBool(_keyIsAnalyticsEnabled, value);
  }

  /// Device Passcode
  bool get isDevicePasscodeEnabled => _getBool(_keyDevicePasscodeEnabled);

  Future<void> setDevicePasscodeEnabled(bool value) async {
    await _setBool(_keyDevicePasscodeEnabled, value);
  }

  /// Notification
  bool get isNotificationEnabled => _getBool(_keyNotificationEnabled);

  Future<void> setNotificationEnabled(bool value) async {
    await _setBool(_keyNotificationEnabled, value);
  }

  /// Beta Features
  bool get isBetaFeaturesEnabled => _getBool(_keyBetaFeaturesEnabled);

  Future<void> setBetaFeaturesEnabled(bool value) async {
    await _setBool(_keyBetaFeaturesEnabled, value);
  }

  /// Explore Bar
  bool get isExploreBarEnabled => _getBool(_keyExploreBarEnabled);

  Future<void> setExploreBarEnabled(bool value) async {
    await _setBool(_keyExploreBarEnabled, value);
  }

  /// Hidden Token IDs
  List<String> get hiddenTokenIDs {
    final result = query([_keyHiddenMainnetTokenIDs]);
    if (result.isEmpty) return [];
    try {
      return (jsonDecode(result.first['value']!) as List<dynamic>)
          .map((e) => e as String)
          .toList();
    } catch (e) {
      log.warning(
          '[SettingsStorageService] Error parsing hiddenMainnetTokenIDs: $e');
      return [];
    }
  }

  Future<void> setHiddenMainnetTokenIDs(List<String> ids) async {
    await write([
      {
        'key': _keyHiddenMainnetTokenIDs,
        'value': jsonEncode(ids),
      }
    ]);
  }

  Future<void> updateHiddenMainnetTokenIDs(
    List<String> tokenIDs,
    bool isAdd, {
    bool override = false,
  }) async {
    List<String> current = override ? [] : hiddenTokenIDs;

    if (isAdd) {
      current.addAll(tokenIDs);
    } else {
      current.removeWhere((id) => tokenIDs.contains(id));
    }

    await setHiddenMainnetTokenIDs(current.toSet().toList());
  }

  /// Selected Device ID
  String? get selectedDeviceId {
    final result = query([_keySelectedDeviceId]);
    if (result.isEmpty) return null;
    try {
      return jsonDecode(result.first['value']!) as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> setSelectedDeviceId(String? deviceId) async {
    if (deviceId == null) {
      await delete([_keySelectedDeviceId]);
    } else {
      await write([
        {
          'key': _keySelectedDeviceId,
          'value': jsonEncode(deviceId),
        }
      ]);
    }
  }

  // ========== Helper Methods ==========

  bool _getBool(String key, {bool defaultValue = false}) {
    final result = query([key]);
    if (result.isEmpty) return defaultValue;
    try {
      return jsonDecode(result.first['value']!) as bool? ?? defaultValue;
    } catch (e) {
      log.warning('[SettingsStorageService] Error parsing $key: $e');
      return defaultValue;
    }
  }

  Future<void> _setBool(String key, bool value) async {
    await write([
      {
        'key': key,
        'value': jsonEncode(value),
      }
    ]);
  }
}
