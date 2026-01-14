// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //

// import 'dart:convert';

// import 'package:autonomy_flutter/service/hive_store_service.dart';
// import 'package:hive_flutter/adapters.dart' as adapters;
// import 'package:json_annotation/json_annotation.dart';

// part 'draft_customer_support.g.dart';

// enum CSMessageType {
//   createIssue,
//   postMessage,
//   postPhotos,
//   postLogs,
// }

// extension RawValue on CSMessageType {
//   String get rawValue => toString().split('.').last;
// }

// class DraftCustomerSupport implements HiveObject {
//   DraftCustomerSupport({
//     required this.uuid,
//     required this.issueID,
//     required this.type,
//     required this.data,
//     required this.createdAt,
//     required this.reportIssueType,
//     this.mutedMessages = '',
//     this.rating = 0,
//   });

//   String uuid;
//   String issueID;
//   String type;
//   String data; // jsonData
//   DateTime createdAt;
//   String reportIssueType;
//   String mutedMessages;
//   int rating;

//   @override
//   String get hiveId => uuid; // ObjectBox requires an id, but we don't use it
// }

// extension Supporter on DraftCustomerSupport {
//   DraftCustomerSupportData get draftData => DraftCustomerSupportData.fromJson(
//         jsonDecode(data) as Map<String, dynamic>,
//       );
// }

// @JsonSerializable()
// class DraftCustomerSupportData {
//   DraftCustomerSupportData({
//     this.text,
//     this.attachments,
//     this.title,
//     this.artworkReportID,
//     this.rating = 0,
//     this.announcementContentId,
//   });

//   factory DraftCustomerSupportData.fromJson(Map<String, dynamic> json) =>
//       _$DraftCustomerSupportDataFromJson(json);
//   String? text;
//   List<LocalAttachment>? attachments;
//   String? title;
//   int rating;
//   String? artworkReportID;
//   String? announcementContentId;

//   Map<String, dynamic> toJson() => _$DraftCustomerSupportDataToJson(this);
// }

// @JsonSerializable()
// class LocalAttachment {
//   LocalAttachment({
//     required this.path,
//     required this.fileName,
//   });

//   factory LocalAttachment.fromJson(Map<String, dynamic> json) =>
//       _$LocalAttachmentFromJson(json);
//   String path;
//   String fileName;

//   Map<String, dynamic> toJson() => _$LocalAttachmentToJson(this);
// }

// class DraftCustomerSupportAdapter
//     extends adapters.TypeAdapter<DraftCustomerSupport> {
//   @override
//   final int typeId = HiveStoreId.draftCustomerSupport.typeId;

//   @override
//   DraftCustomerSupport read(adapters.BinaryReader reader) {
//     final json = jsonDecode(reader.readString()) as Map<String, dynamic>;
//     return DraftCustomerSupport(
//       uuid: json['uuid'] as String,
//       issueID: json['issueID'] as String,
//       type: json['type'] as String,
//       data: json['data'] as String,
//       createdAt: DateTime.parse(json['createdAt'] as String),
//       reportIssueType: json['reportIssueType'] as String,
//       mutedMessages: json['mutedMessages'] as String? ?? '',
//       rating: (json['rating'] as num?)?.toInt() ?? 0,
//     );
//   }

//   @override
//   void write(adapters.BinaryWriter writer, DraftCustomerSupport obj) {
//     final json = {
//       'uuid': obj.uuid,
//       'issueID': obj.issueID,
//       'type': obj.type,
//       'data': obj.data,
//       'createdAt': obj.createdAt.toIso8601String(),
//       'reportIssueType': obj.reportIssueType,
//       'mutedMessages': obj.mutedMessages,
//       'rating': obj.rating,
//     };
//     writer.writeString(jsonEncode(json));
//   }
// }
