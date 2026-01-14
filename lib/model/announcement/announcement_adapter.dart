// import 'package:autonomy_flutter/model/announcement/announcement_local.dart';
// import 'package:autonomy_flutter/service/hive_store_service.dart';
// import 'package:hive_flutter/hive_flutter.dart';

// class AnnouncementLocalAdapter extends TypeAdapter<AnnouncementLocal> {
//   @override
//   final int typeId = HiveStoreId.announcement.typeId;

//   @override
//   AnnouncementLocal read(BinaryReader reader) =>
//       AnnouncementLocal.addFromAdditionalData(
//         announcementContentId: reader.readString(),
//         content: reader.readString(),
//         additionalData: reader.readMap().cast<String, dynamic>(),
//         startedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
//         endedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
//         read: reader.readBool(),
//       );

//   @override
//   void write(BinaryWriter writer, AnnouncementLocal obj) {
//     obj.additionalData['~inAppEnabled'] = obj.inAppEnabled;
//     obj.additionalData['~notificationType'] =
//         obj.notificationType?.toShortString();
//     writer
//       ..writeString(obj.announcementContentId)
//       ..writeString(obj.content)
//       ..writeMap(obj.additionalData)
//       ..writeInt(obj.startedAt.millisecondsSinceEpoch)
//       ..writeInt(obj.endedAt.millisecondsSinceEpoch)
//       ..writeBool(obj.read);
//   }
// }
