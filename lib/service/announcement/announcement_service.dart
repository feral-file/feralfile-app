import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/gateway/iap_api.dart';
import 'package:autonomy_flutter/model/additional_data/additional_data.dart';
import 'package:autonomy_flutter/model/announcement/announcement.dart';
import 'package:autonomy_flutter/model/announcement/announcement_local.dart';
import 'package:autonomy_flutter/model/announcement/announcement_request.dart';
import 'package:autonomy_flutter/model/announcement/notification_setting_type.dart';
import 'package:autonomy_flutter/service/announcement/announcement_store.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/inapp_notifications.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:synchronized/synchronized.dart';

abstract class AnnouncementService {
  Future<List<Announcement>> fetchAnnouncements();

  List<AnnouncementLocal> getLocalAnnouncements();

  Future<void> markAsRead(String? announcementContentId);

  AnnouncementLocal? getAnnouncement(String? announcementContentId);

  Future<void> showOldestAnnouncement({bool shouldRepeat = true});

  void linkAnnouncementToIssue(String announcementContentId, String issueId);

  Announcement? findAnnouncementByIssueId(String issueId);

  String? findIssueIdByAnnouncement(String announcementContentId);
}

class AnnouncementServiceImpl implements AnnouncementService {
  final IAPApi _iapApi;
  final AnnouncementStore _announcementStore;
  final ConfigurationService _configurationService;

  AnnouncementServiceImpl(
    this._iapApi,
    this._announcementStore,
    this._configurationService,
  );

  // queue of unread announcements, use this to avoid access to hive box
  final List<AnnouncementLocal> _queue = [];
  final Lock _lock = Lock();

  static const int _fetchSize = 10;

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    final lastPullTime = _configurationService.getLastPullAnnouncementTime();
    final request = AnnouncementRequest(
      lastPullTime: lastPullTime,
      size: _fetchSize,
    );
    log.info('Fetching announcements with request: ${request.toJson()}');
    late List<Announcement> announcements;
    try {
      announcements = await _iapApi.getAnnouncements(request);
      final localAnnouncement = _announcementStore.getAll();
      announcements.removeWhere((element) => localAnnouncement.any((local) =>
          local.announcementContentId == element.announcementContentId));
      for (final announcement in announcements) {
        final localAnnouncement =
            AnnouncementLocal.fromAnnouncement(announcement);
        await _saveAnnouncement(localAnnouncement);

        if (_queue.isNotEmpty &&
            !_queue.any((element) =>
                element.announcementContentId ==
                localAnnouncement.announcementContentId)) {
          _queue.add(localAnnouncement);
        }
      }
      await _configurationService.setLastPullAnnouncementTime(
          DateTime.now().millisecondsSinceEpoch ~/ 1000);
    } catch (e) {
      log.info('Error fetching announcements: $e');
      return [];
    }
    log.info('Fetched announcements: ${announcements.length}');
    _updateBadger(_queue.length);
    return announcements;
  }

  @override
  List<AnnouncementLocal> getLocalAnnouncements() {
    final announcements = _announcementStore.getAll()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return announcements;
  }

  @override
  Future<void> markAsRead(String? announcementContentId) async {
    if (announcementContentId == null) {
      return;
    }
    final announcement = _announcementStore.get(announcementContentId);
    if (announcement != null) {
      await _markAsReadAnnouncement(announcement);
    }
  }

  Future<void> _markAsReadAnnouncement(AnnouncementLocal announcement) async {
    _queue.removeWhere((element) =>
        element.announcementContentId == announcement.announcementContentId);
    _updateBadger(_queue.length);
    await _saveAnnouncement(announcement.markAsRead());
  }

  /// unread and in-app enabled announcements
  List<AnnouncementLocal> _getAnnouncementsToShow() {
    _queue.removeWhere((element) => !_shouldDisplayAnnouncement(element));
    if (_queue.isEmpty) {
      final allAnnouncements = getLocalAnnouncements();
      _queue.addAll(allAnnouncements
          .where((element) => _shouldDisplayAnnouncement(element))
          .toList());
    }
    _updateBadger(_queue.length);
    return _queue;
  }

  bool _shouldDisplayAnnouncement(AnnouncementLocal announcement) =>
      !announcement.read &&
      announcement.inAppEnabled &&
      announcement.notificationType == NotificationSettingType.announcement;

  @override
  AnnouncementLocal? getAnnouncement(String? announcementContentId) {
    if (announcementContentId == null) {
      return null;
    }
    return _announcementStore.get(announcementContentId);
  }

  AnnouncementLocal? _getOldestUnreadAnnouncement() {
    final announcements = _getAnnouncementsToShow();
    return announcements.firstOrNull;
  }

  @override
  Future<void> showOldestAnnouncement({bool shouldRepeat = true}) async {
    final announcement = _getOldestUnreadAnnouncement();
    if (announcement != null) {
      final context = injector<NavigationService>().context;
      final data = announcement.additionalData;
      data['announcementContentID'] = announcement.announcementContentId;
      final additionalData =
          AdditionalData.fromJson(announcement.additionalData);

      /// If the announcement is expired, mark it as read and show the next one
      if (announcement.isExpired) {
        await _markAsReadAnnouncement(announcement);
        if (shouldRepeat) {
          await showOldestAnnouncement();
        }
        return;
      }
      await showInAppNotifications(
        context,
        announcement.announcementContentId,
        additionalData,
        body: announcement.content,
        handler: additionalData.isTappable
            ? () async {
                await additionalData.handleTap(context);
              }
            : null,
        callBackOnDismiss: () async {
          if (shouldRepeat) {
            await showOldestAnnouncement();
          }
        },
      );
    }
  }

  void _updateBadger(int count) {
    if (!OneSignal.Notifications.permission) {
      // we dont ask for notification permission
      log.info('[_updateBadger] Notification permission is not granted');
      return;
    }
    // if (count > 0) {
    //   unawaited(FlutterAppBadger.updateBadgeCount(count));
    // } else {
    //   unawaited(FlutterAppBadger.removeBadge());
    // }
  }

  Future<void> _saveAnnouncement(AnnouncementLocal announcement) async {
    await _lock.synchronized(() async {
      await _announcementStore.save(
          announcement, announcement.announcementContentId);
    });
  }

  @override
  void linkAnnouncementToIssue(String announcementContentId, String issueId) {
    injector<ConfigurationService>()
        .setLinkAnnouncementToIssue(announcementContentId, issueId);
  }

  @override
  Announcement? findAnnouncementByIssueId(String issueId) {
    final announcementId = injector<ConfigurationService>()
        .getAnnouncementContentIdByIssueId(issueId);
    if (announcementId != null) {
      return _announcementStore.get(announcementId);
    } else {
      return null;
    }
  }

  @override
  String? findIssueIdByAnnouncement(String announcementContentId) =>
      injector<ConfigurationService>()
          .getIssueIdByAnnouncementContentId(announcementContentId);
}
