// import 'package:autonomy_flutter/model/announcement/notification_setting_type.dart';
// import 'package:autonomy_flutter/model/customer_support.dart';
// import 'package:easy_localization/easy_localization.dart';

// class Announcement extends ChatThread {
//   final String announcementContentId;
//   final String content;
//   final Map<String, dynamic> additionalData;
//   final DateTime startedAt;
//   final DateTime endedAt;
//   final String? imageURL;
//   final NotificationSettingType? notificationType;
//   final String? deliveryTimeOfDay;
//   final bool inAppEnabled;

//   Announcement({
//     required this.announcementContentId,
//     required this.content,
//     required this.additionalData,
//     required this.startedAt,
//     required this.endedAt,
//     required this.inAppEnabled,
//     required this.notificationType,
//     this.imageURL,
//     this.deliveryTimeOfDay,
//   });

//   factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
//         announcementContentId: json['notificationContentID'] as String,
//         content: json['content'] as String,
//         additionalData: (json['additionalData'] ?? <String, dynamic>{})
//             as Map<String, dynamic>,
//         startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
//             DateTime.now(),
//         endedAt: DateTime.tryParse(json['endedAt'] as String? ?? '') ??
//             DateTime.now().add(const Duration(days: 365)),
//         imageURL: json['imageURL'] as String?,
//         notificationType: NotificationSettingType.fromString(
//           json['notificationType'] as String? ?? '',
//         ),
//         deliveryTimeOfDay: json['deliveryTimeOfDay'] as String?,
//         inAppEnabled: json['inAppEnabled'] as bool,
//       );

//   bool get isExpired => DateTime.now().isAfter(endedAt);

//   @override
//   String getListTitle() => 'chat_with_feralfile'.tr();

//   @override
//   bool isUnread() => false;

//   @override
//   DateTime get sortTime => startedAt;
// }
