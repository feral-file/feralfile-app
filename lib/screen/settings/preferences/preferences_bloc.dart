//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/au_bloc.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_state.dart';
import 'package:autonomy_flutter/service/local_auth_service.dart';
import 'package:autonomy_flutter/util/biometrics_util.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:local_auth/local_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class PreferencesBloc extends AuBloc<PreferenceEvent, PreferenceState> {
  PreferencesBloc(this._appDataManager)
      : super(PreferenceState(false, false, false, '', false, false, false)) {
    final appSettingsStorageService = _appDataManager.appSettingsStorageService;
    on<PreferenceInfoEvent>((event, emit) async {
      _availableBiometrics = await _localAuth.getAvailableBiometrics();
      final canCheckBiometrics = await authenticateIsAvailable();

      final passcodeEnabled = appSettingsStorageService.isDevicePasscodeEnabled;
      final notificationEnabled =
          appSettingsStorageService.isNotificationEnabled &&
              OneSignal.Notifications.permission;
      final analyticsEnabled = appSettingsStorageService.isAnalyticsEnabled;
      final betaFeaturesEnabled =
          appSettingsStorageService.isBetaFeaturesEnabled;
      final exploreBarEnabled = appSettingsStorageService.isExploreBarEnabled;

      final hasHiddenArtwork =
          appSettingsStorageService.hiddenTokenIDs.isNotEmpty;

      emit(PreferenceState(
          passcodeEnabled && canCheckBiometrics,
          notificationEnabled,
          analyticsEnabled,
          _authMethodTitle(),
          hasHiddenArtwork,
          betaFeaturesEnabled,
          exploreBarEnabled));
    });

    on<PreferenceUpdateEvent>((event, emit) async {
      _isOnChanging = true;
      if (event.newState.isDevicePasscodeEnabled !=
          state.isDevicePasscodeEnabled) {
        final canCheckBiometrics = await authenticateIsAvailable();
        if (canCheckBiometrics) {
          bool didAuthenticate = false;
          try {
            didAuthenticate = await LocalAuthenticationService.authenticate(
                localizedReason: 'authen_for_autonomy'.tr());
          } catch (e) {
            log.info(e);
          }
          if (didAuthenticate) {
            await appSettingsStorageService.setDevicePasscodeEnabled(
                event.newState.isDevicePasscodeEnabled);
          } else {
            event.newState.isDevicePasscodeEnabled =
                state.isDevicePasscodeEnabled;
          }
        } else {
          event.newState.isDevicePasscodeEnabled = false;
          unawaited(openAppSettings());
        }
      }

      if (event.newState.isNotificationEnabled != state.isNotificationEnabled) {
        try {
          await appSettingsStorageService
              .setNotificationEnabled(event.newState.isNotificationEnabled);
        } catch (error) {
          log.warning('Error when setting notification: $error');
        }
      }

      if (event.newState.isAnalyticEnabled != state.isAnalyticEnabled) {
        await appSettingsStorageService
            .setAnalyticsEnabled(event.newState.isAnalyticEnabled);
      }

      if (event.newState.isBetaFeaturesEnabled != state.isBetaFeaturesEnabled) {
        await appSettingsStorageService
            .setBetaFeaturesEnabled(event.newState.isBetaFeaturesEnabled);
        // If beta features are disabled, also disable explore bar
        if (!event.newState.isBetaFeaturesEnabled) {
          event.newState.isExploreBarEnabled = false;
        }
      }

      if (event.newState.isExploreBarEnabled != state.isExploreBarEnabled) {
        // Only allow enabling explore bar if beta features are enabled
        if (event.newState.isExploreBarEnabled &&
            !event.newState.isBetaFeaturesEnabled) {
          event.newState.isExploreBarEnabled = false;
        } else {
          await appSettingsStorageService
              .setExploreBarEnabled(event.newState.isExploreBarEnabled);
        }
      }

      _isOnChanging = false;
      emit(event.newState);
    });
  }
  final AppDataManager _appDataManager;
  final LocalAuthentication _localAuth = LocalAuthentication();
  List<BiometricType> _availableBiometrics = List.empty();
  static bool _isOnChanging = false;

  static bool get isOnChanging => _isOnChanging;

  String _authMethodTitle() {
    if (Platform.isIOS) {
      if (_availableBiometrics.contains(BiometricType.face)) {
        // Face ID.
        return 'face_id'.tr();
      } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
        // Touch ID.
        return 'touch_id'.tr();
      }
    }

    return 'device_passcode'.tr();
  }
}
