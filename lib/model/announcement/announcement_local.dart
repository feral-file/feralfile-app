// import 'package:autonomy_flutter/model/announcement/announcement.dart';
// import 'package:autonomy_flutter/model/announcement/notification_setting_type.dart';

// class AnnouncementLocal extends Announcement {
//   bool read;

//   AnnouncementLocal._({
//     required super.announcementContentId,
//     required super.content,
//     required super.additionalData,
//     required super.startedAt,
//     required super.endedAt,
//     required super.inAppEnabled,
//     required super.notificationType,
//     this.read = false,
//   });

//   static AnnouncementLocal addFromAdditionalData({
//     required String announcementContentId,
//     required String content,
//     required Map<String, dynamic> additionalData,
//     required DateTime startedAt,
//     required DateTime endedAt,
//     required bool read,
//   }) =>
//       AnnouncementLocal._(
//         announcementContentId: announcementContentId,
//         content: content,
//         additionalData: additionalData,
//         startedAt: startedAt,
//         endedAt: endedAt,
//         inAppEnabled: additionalData['~inAppEnabled'] as bool? ?? true,
//         notificationType: NotificationSettingType.fromString(
//           additionalData['~notificationType'] as String? ?? '',
//         ),
//         read: read,
//       );

//   AnnouncementLocal markAsRead() {
//     read = true;
//     return this;
//   }

//   static AnnouncementLocal fromAnnouncement(Announcement announcement) =>
//       AnnouncementLocal._(
//         announcementContentId: announcement.announcementContentId,
//         content: announcement.content,
//         additionalData: announcement.additionalData,
//         startedAt: announcement.startedAt,
//         endedAt: announcement.endedAt,
//         inAppEnabled: announcement.inAppEnabled,
//         notificationType: announcement.notificationType,
//       );

//   @override
//   bool isUnread() => !read;
// }
