import 'dart:async';

import 'package:autonomy_flutter/model/additional_data/announcement_data.dart';
import 'package:autonomy_flutter/model/additional_data/call_to_action.dart';
import 'package:autonomy_flutter/model/additional_data/chat_notification_data.dart';
import 'package:autonomy_flutter/model/additional_data/cs_view_thread.dart';
import 'package:autonomy_flutter/model/additional_data/navigate_additional_data.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/notification_type.dart';
import 'package:flutter/cupertino.dart';

class AdditionalData {
  AdditionalData({
    required this.notificationType,
    this.announcementContentId,
    this.cta,
    this.title,
    this.listCustomCta,
  });
  final NotificationType notificationType;
  final String? announcementContentId;
  final String? title;
  final CallToAction? cta;
  final List<CallToAction>? listCustomCta;

  bool get isTappable => false;

  static AdditionalData fromJson(Map<String, dynamic> json, {String? type}) {
    final notificationContentId = json['notification_content_id'] as String?;
    try {
      final notificationType = NotificationType.fromString(
        type ?? json['notification_type'] as String,
      );
      final title = json['title'] as String?;
      final cta = json['cta'] == null
          ? null
          : CallToAction.fromJson(
              Map<String, dynamic>.from(
                Map<String, dynamic>.from(json['cta'] as Map),
              ),
            );

      final defaultAdditionalData = AdditionalData(
        notificationType: notificationType,
        announcementContentId: notificationContentId,
        cta: cta,
        title: title,
      );

      switch (notificationType) {
        case NotificationType.supportMessage:
          return ChatNotificationData(
            notificationType: notificationType,
            announcementContentId: notificationContentId,
            cta: cta,
            title: title,
          );
        case NotificationType.announcement:
          final listCustomCta = json['custom_data'] != null &&
                  json['custom_data']['button_cta_list'] != null
              ? (json['custom_data']['button_cta_list'] as List)
                  .map(
                    (e) => CallToAction.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList()
              : null;

          return AnnouncementData(
            notificationType: notificationType,
            announcementContentId: notificationContentId,
            cta: cta,
            title: title,
            listCustomCta: listCustomCta,
          );

        case NotificationType.customerSupportNewMessage:
        case NotificationType.customerSupportCloseIssue:
          final issueId = json['issue_id'];
          if (issueId == null) {
            log.warning('AdditionalData: issueId is null');
            return defaultAdditionalData;
          }
          return CsViewThread(
            issueId: issueId.toString(),
            notificationType: notificationType,
            announcementContentId: notificationContentId,
            cta: cta,
          );
        case NotificationType.navigate:
          final navigationRoute = json['navigation_route'] as String;
          final homeIndex = json['home_index'] as int;
          return NavigateAdditionalData(
            navigationRoute: navigationRoute,
            notificationType: notificationType,
            announcementContentId: notificationContentId,
            homeIndex: homeIndex,
            cta: cta,
          );

        default:
          return defaultAdditionalData;
      }
    } catch (_) {
      log.info('AdditionalData: error parsing additional data');
      return AdditionalData(
        notificationType: NotificationType.general,
        announcementContentId: notificationContentId,
      );
    }
  }

  Future<void> handleTap(BuildContext context) async {
    log.info('AdditionalData: handle tap: $notificationType');
  }

  FutureOr<bool> prepareAndDidSuccess() => true;
}
