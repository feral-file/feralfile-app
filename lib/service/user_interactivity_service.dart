import 'dart:async';
import 'dart:math' as math;

import 'package:autonomy_flutter/model/dailies.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

abstract class UserInteractivityService {
  Future<void> likeDailyWork(DailyToken dailyToken);
}

class UserInteractivityServiceImpl implements UserInteractivityService {
  UserInteractivityServiceImpl(this._configurationService);
  final ConfigurationService _configurationService;

  @override
  Future<void> likeDailyWork(DailyToken dailyToken) async {
    await _countDailyLiked();
  }

  Future<void> _countDailyLiked() async {
    final isNotificationEnabled = OneSignal.Notifications.permission;
    if (!isNotificationEnabled) {
      final likedCount = _configurationService.getDailyLikedCount();
      if (likedCount >= 3) {
        await _showEnableNotificationDialog();
      } else {
        await _configurationService.setDailyLikedCount(likedCount + 1);
      }
    }
  }

  Future<dynamic> _showEnableNotificationDialog() async {
    final type = EnableNotificationPromptType.getRandomType();
    await UIHelper.showNotificationPrompt(type);
    await _configurationService.setDailyLikedCount(0);
  }
}

enum EnableNotificationPromptType {
  stayUpdate,
  getUpdate,
  neverMiss,
  ;

  String get title {
    switch (this) {
      case EnableNotificationPromptType.stayUpdate:
        return 'stay_updated_new_art'.tr();
      case EnableNotificationPromptType.getUpdate:
        return 'get_daily_updated'.tr();
      case EnableNotificationPromptType.neverMiss:
        return 'never_miss_tomorrow_art'.tr();
    }
  }

  String get description {
    switch (this) {
      case EnableNotificationPromptType.stayUpdate:
        return 'stay_updated_new_art_desc'.tr();
      case EnableNotificationPromptType.getUpdate:
        return 'get_daily_updated_desc'.tr();
      case EnableNotificationPromptType.neverMiss:
        return 'never_miss_tomorrow_art_desc'.tr();
    }
  }

  static EnableNotificationPromptType getRandomType() {
    const values = EnableNotificationPromptType.values;
    return values[math.Random().nextInt(values.length)];
  }
}
