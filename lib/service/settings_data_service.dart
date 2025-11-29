//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:convert';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/graphql/account_settings/cloud_manager.dart';
import 'package:autonomy_flutter/model/play_list_model.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

abstract class SettingsDataService {
  Future<void> restoreSettingsData();

  Future<void> backupDeviceSettings();

  Future<void> backupUserSettings();
}

class SettingsDataServiceImpl implements SettingsDataService {
  SettingsDataServiceImpl(
    this._configurationService,
    this._cloudObject,
  );

  final ConfigurationService _configurationService;
  final CloudManager _cloudObject;

  // legacy settings, they were store in device settings
  static const _keyPlaylists = 'playlists';

  // device settings
  static const _keyIsAnalyticsEnabled = 'isAnalyticsEnabled';
  static const _keyDevicePasscodeEnabled = 'devicePasscodeEnabled';
  static const _keyNotificationEnabled = 'notificationEnabled';
  static const _deviceSettingsKeys = [
    _keyIsAnalyticsEnabled,
    _keyDevicePasscodeEnabled,
    _keyNotificationEnabled,
    _keyPlaylists,
  ];

  // user settings
  static const _keyHiddenMainnetTokenIDs = 'hiddenMainnetTokenIDs';
  static const _keySelectedDeviceId = 'selectedDeviceId';

  static const _userSettingsKeys = [
    _keyHiddenMainnetTokenIDs,
    _keySelectedDeviceId,
  ];

  @override
  Future<void> restoreSettingsData() async {
    if (PreferencesBloc.isOnChanging) {
      log.info('[SettingsDataService] skip restore: on changing preference');
      return;
    }
    log.info('[SettingsDataService][Start] restoreSettingsData');

    await Future.wait([
      _cloudObject.deviceSettingsDB.download(keys: _deviceSettingsKeys),
      _cloudObject.userSettingsDB.download(keys: _userSettingsKeys),
    ]);

    final data = <String, dynamic>{}
      ..addAll(
        _cloudObject.deviceSettingsDB.allInstance
            .map((key, value) => MapEntry(key, jsonDecode(value))),
      )
      ..addAll(
        _cloudObject.userSettingsDB.allInstance
            .map((key, value) => MapEntry(key, jsonDecode(value))),
      );

    log.info('[SettingsDataService] restore $data');

    await _saveSettingToConfig(data);
  }

  Future<void> _saveSettingToConfig(Map<String, dynamic> data) async {
    await _configurationService
        .setAnalyticEnabled(data[_keyIsAnalyticsEnabled] as bool? ?? true);

    await _configurationService.setDevicePasscodeEnabled(
      data[_keyDevicePasscodeEnabled] as bool? ?? false,
    );

    await _configurationService.setNotificationEnabled(
        data[_keyNotificationEnabled] as bool? ?? false);

    await _configurationService.updateTempStorageHiddenTokenIDs(
      (data[_keyHiddenMainnetTokenIDs] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      true,
      override: true,
    );

    await _configurationService.setSelectedDeviceId(
      data[_keySelectedDeviceId] as String?,
    );

    final legacyPlaylists = (data[_keyPlaylists] as List<dynamic>?)
        ?.map((e) => PlayListModel.fromJson(e as Map<String, dynamic>))
        .toList();
    if (legacyPlaylists != null && legacyPlaylists.isNotEmpty) {
      await injector<CloudManager>()
          .playlistCloudObject
          .setPlaylists(legacyPlaylists);
      await _cloudObject.deviceSettingsDB.delete([_keyPlaylists]);
    }
  }

  @override
  Future<void> backupDeviceSettings() async {
    final currentSettings = _cloudObject.deviceSettingsDB.allInstance;
    final newSettings = <Map<String, String>>[];

    final isAnalyticsEnabled =
        jsonEncode(_configurationService.isAnalyticsEnabled());
    if (currentSettings[_keyIsAnalyticsEnabled] != isAnalyticsEnabled) {
      newSettings.add({
        'key': _keyIsAnalyticsEnabled,
        'value': isAnalyticsEnabled,
      });
    }

    final devicePasscodeEnabled =
        jsonEncode(_configurationService.isDevicePasscodeEnabled());
    if (currentSettings[_keyDevicePasscodeEnabled] != devicePasscodeEnabled) {
      newSettings.add({
        'key': _keyDevicePasscodeEnabled,
        'value': devicePasscodeEnabled,
      });
    }

    final notificationEnabled =
        jsonEncode(_configurationService.isNotificationEnabled());
    if (currentSettings[_keyNotificationEnabled] != notificationEnabled) {
      newSettings.add({
        'key': _keyNotificationEnabled,
        'value': notificationEnabled,
      });
    }

    if (newSettings.isEmpty) {
      log.info('[SettingsDataService] skip device backup: identical');
      return;
    }

    try {
      await _cloudObject.deviceSettingsDB.write(newSettings);

      log.info('[SettingsDataService][Done] backup device settings');
    } catch (exception, stacktrace) {
      await Sentry.captureException(exception, stackTrace: stacktrace);
      return;
    }
  }

  @override
  Future<void> backupUserSettings() async {
    final currentSettings = _cloudObject.userSettingsDB.allInstance;
    final newSettings = <Map<String, String>>[];

    final hiddenMainnetTokenIDs =
        jsonEncode(_configurationService.getTempStorageHiddenTokenIDs());
    if (currentSettings[_keyHiddenMainnetTokenIDs] != hiddenMainnetTokenIDs) {
      newSettings.add({
        'key': _keyHiddenMainnetTokenIDs,
        'value': hiddenMainnetTokenIDs,
      });
    }

    // backup SelectedDeviceId
    final selectedDeviceId =
        jsonEncode(_configurationService.getSelectedDeviceId());
    if (currentSettings['selectedDeviceId'] != selectedDeviceId) {
      newSettings.add({
        'key': _keySelectedDeviceId,
        'value': selectedDeviceId,
      });
    }

    if (newSettings.isEmpty) {
      log.info('[SettingsDataService] skip user backup: identical');
      return;
    }

    try {
      await _cloudObject.userSettingsDB.write(newSettings);

      log.info('[SettingsDataService][Done] backup user settings');
    } catch (exception, stacktrace) {
      await Sentry.captureException(exception, stackTrace: stacktrace);
      return;
    }
  }
}
