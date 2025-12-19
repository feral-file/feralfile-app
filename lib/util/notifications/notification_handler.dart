import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/additional_data/additional_data.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/util/inapp_notifications.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/notifications/notification_type.dart';
import 'package:flutter/material.dart';

class NotificationHandler {
  // singleton
  static final NotificationHandler instance = NotificationHandler._();

  NotificationHandler._();

  final AnnouncementService _announcementService =
      injector<AnnouncementService>();

  Future<void> handlePushNotificationClicked(
    BuildContext context,
    AdditionalData additionalData,
  ) async {
    log.info('handlePushNotificationClicked');
    if (additionalData.notificationType != NotificationType.announcement) {
      await _announcementService
          .markAsRead(additionalData.announcementContentId);
      if (!context.mounted) {
        return;
      }
      await additionalData.handleTap(context);
    } else {
      if (!context.mounted) {
        return;
      }
      await showInAppNotifications(
        context,
        additionalData.announcementContentId ?? '',
        additionalData,
      );
    }
  }
}
