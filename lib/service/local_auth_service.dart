import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/util/biometrics_util.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sentry/sentry_io.dart';

class LocalAuthenticationService {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static int _count = 0;
  static Timer? _resetTimer;
  static const int _maxCount = 3;

  static Future<bool> authenticate({required String localizedReason}) async {
    final result = await _localAuth.authenticate(
      localizedReason: localizedReason,
    );
    _resetTimer?.cancel();
    if (result) {
      _count = 0;
    } else {
      _count++;
      if (_count >= _maxCount) {
        // capture sentry event
        log.info('Local auth failed $_count times');
        unawaited(Sentry.captureMessage('Local auth failed $_count times'));
        _count = 0;
      } else {
        _resetTimer = Timer(const Duration(minutes: 1), () {
          _count = 0;
        });
      }
    }
    return result;
  }

  static Future<bool> checkLocalAuth() async {
    final appDataManager = injector<AppDataManager>();
    final isAvailable = await authenticateIsAvailable();
    final isDevicePasscodeEnabled =
        appDataManager.appSettingsStorageService.isDevicePasscodeEnabled;

    if (isDevicePasscodeEnabled && isAvailable) {
      bool didAuthenticate = false;
      try {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'authen_for_autonomy'.tr(),
        );
      } catch (e) {
        log.info('authenticate error $e');
      }
      return didAuthenticate;
    }
    return true;
  }
}
