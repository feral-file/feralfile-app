// //
// //  SPDX-License-Identifier: BSD-2-Clause-Patent
// //  Copyright © 2022 Bitmark. All rights reserved.
// //  Use of this source code is governed by the BSD-2-Clause Plus Patent License
// //  that can be found in the LICENSE file.
// //

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:autonomy_flutter/common/environment.dart';
// import 'package:autonomy_flutter/common/injector.dart';
// import 'package:autonomy_flutter/gateway/customer_support_api.dart';
// import 'package:autonomy_flutter/model/announcement/announcement_local.dart';
// import 'package:autonomy_flutter/model/customer_support.dart';
// import 'package:autonomy_flutter/model/draft_customer_support.dart';
// import 'package:autonomy_flutter/service/bluetooth_service.dart';
// import 'package:autonomy_flutter/service/configuration_service.dart';
// import 'package:autonomy_flutter/service/hive_store_service.dart';
// import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
// import 'package:autonomy_flutter/util/device.dart';
// import 'package:autonomy_flutter/util/log.dart';
// import 'package:autonomy_flutter/view/user_agent_utils.dart';
// import 'package:collection/collection.dart';
// import 'package:flutter/material.dart';
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';

// class CustomerSupportUpdate {
//   CustomerSupportUpdate({
//     required this.draft,
//     required this.response,
//   });

//   DraftCustomerSupport draft;
//   PostedMessageResponse response;
// }

// abstract class CustomerSupportService {
//   ValueNotifier<List<int>?>
//       get numberOfIssuesInfo; // [numberOfIssues, numberOfUnreadIssues]

//   Future<void> init();

//   ValueNotifier<int> get triggerReloadMessages;

//   ValueNotifier<CustomerSupportUpdate?> get customerSupportUpdate;

//   Map<String, String> get tempIssueIDMap;

//   List<String>? get errorMessages;

//   Future<IssueDetails> getDetails(String issueID);

//   Future draftMessage(DraftCustomerSupport draft);

//   Future processMessages();

//   Future<List<DraftCustomerSupport>> getDrafts(String issueID);

//   Future<String> getStoredDirectory();

//   Future<String> storeFile(String filename, List<int> bytes);

//   Future reopen(String issueID);

//   Future rateIssue(String issueID, int rating);

//   Future<void> removeErrorMessage(String uuid, {bool isDelete = false});

//   void sendMessageFail(String uuid);

//   Future<void> clear();
// }

// class DraftCustomerSupportStore
//     extends HiveStoreObjectServiceImpl<DraftCustomerSupport> {
//   static const String _key = 'draft.customer_support';

//   DraftCustomerSupportStore() : super(key: _key);

//   @override
//   Future<void> init() async {
//     await super.init();
//   }
// }

// class CustomerSupportServiceImpl extends CustomerSupportService {
//   CustomerSupportServiceImpl(
//     this._draftCustomerSupportStore,
//     this._customerSupportApi,
//     this._configurationService,
//   );

// // 1 day.

//   final DraftCustomerSupportStore _draftCustomerSupportStore;
//   final CustomerSupportApi _customerSupportApi;
//   final ConfigurationService _configurationService;

//   @override
//   List<String> errorMessages = [];
//   int retryTime = 0;

//   @override
//   ValueNotifier<List<int>?> numberOfIssuesInfo = ValueNotifier(null);
//   @override
//   ValueNotifier<int> triggerReloadMessages = ValueNotifier(0);
//   @override
//   ValueNotifier<CustomerSupportUpdate?> customerSupportUpdate =
//       ValueNotifier(null);
//   @override
//   Map<String, String> tempIssueIDMap = {};

//   bool _isProcessingDraftMessages = false;

//   /// will add this after backend support
//   static const _supportChatNotificationTypes = [];

//   @override
//   Future<void> init() async {
//     await _draftCustomerSupportStore.init();
//   }

//   Future<List<Issue>> _getIssues() async {
//     final issues = <Issue>[];
//     try {
//       final deviceId = await _configurationService.getDeviceId();
//       final listAnonymousIssues = await _customerSupportApi.getAnonymousIssues(
//         apiKey: Environment.supportApiKey,
//         deviceId: deviceId,
//       );
//       issues
//         ..addAll(listAnonymousIssues)
//         ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
//     } catch (e) {
//       log.info('[CS-Service] getIssues error: $e');
//       unawaited(Sentry.captureException(e));
//     }
//     final drafts = _draftCustomerSupportStore.getAll();

//     for (final draft in drafts) {
//       if (draft.type != CSMessageType.createIssue.rawValue) {
//         continue;
//       }

//       final draftData = draft.draftData;

//       var issueTitle = draftData.title ?? draftData.text;
//       if (issueTitle == null || issueTitle.isEmpty) {
//         issueTitle =
//             draftData.attachments != null && draftData.attachments!.isNotEmpty
//                 ? draftData.attachments!.first.fileName
//                 : 'Unnamed';
//       }

//       final draftIssue = Issue(
//         issueID: draft.issueID,
//         status: 'open',
//         title: issueTitle,
//         tags: [draft.reportIssueType],
//         timestamp: draft.createdAt,
//         total: 1,
//         unread: 0,
//         lastMessage: null,
//         firstMessage: null,
//         draft: draft,
//         rating: draft.rating,
//       );
//       issues.add(draftIssue);
//     }

//     for (final issue in issues) {
//       try {
//         final latestDraft = drafts.firstWhere(
//           (element) =>
//               element.issueID == issue.issueID &&
//               element.type != CSMessageType.createIssue.rawValue,
//         );

//         issue.draft = latestDraft;
//       } catch (_) {
//         continue;
//       }
//     }
//     return issues;
//   }

//   @override
//   Future<IssueDetails> getDetails(String issueID) async =>
//       _customerSupportApi.getDetails(issueID);

//   @override
//   Future<dynamic> draftMessage(DraftCustomerSupport draft) async {
//     await _draftCustomerSupportStore.save(draft, draft.hiveId);
//     unawaited(processMessages());
//   }

//   @override
//   Future<void> removeErrorMessage(String uuid, {bool isDelete = false}) async {
//     retryTime = 0;
//     final id = uuid.substring(0, 36);
//     errorMessages.remove(id);
//     if (isDelete) {
//       final msg = _draftCustomerSupportStore.getAll().firstWhereOrNull(
//             (element) => element.uuid == id,
//           );
//       if (msg != null) {
//         await _draftCustomerSupportStore.delete(msg.hiveId);
//         if (msg.draftData.attachments != null &&
//             msg.draftData.attachments!.isNotEmpty) {
//           final draftData = msg.draftData;
//           final name = uuid.substring(36);
//           final fileToRemove = draftData.attachments!
//               .firstWhereOrNull((element) => element.fileName.contains(name));
//           if (draftData.attachments!.remove(fileToRemove)) {
//             msg.data = jsonEncode(draftData);
//             await _draftCustomerSupportStore.save(msg, msg.hiveId);
//             errorMessages.add(id);
//           }
//           if (msg.type == CSMessageType.postLogs.rawValue &&
//               fileToRemove != null) {
//             final file = File(fileToRemove.path);
//             unawaited(file.delete());
//           }
//         }
//       }
//     }
//   }

//   @override
//   void sendMessageFail(String uuid) {
//     if (retryTime > 5) {
//       errorMessages.add(uuid);
//       retryTime = 0;
//     }
//   }

//   @override
//   Future<void> processMessages() async {
//     log.info('[CS-Service][trigger] processMessages');
//     if (_isProcessingDraftMessages) {
//       return;
//     }
//     log.info('[CS-Service][start] processMessages');
//     final draftMsgsRaw = _draftCustomerSupportStore.getAll();
//     if (draftMsgsRaw.isEmpty) {
//       return;
//     }
//     final draftMsg = draftMsgsRaw
//         .firstWhereOrNull((element) => !errorMessages.contains(element.uuid));
//     if (draftMsg == null) {
//       return;
//     }
//     log.info('[CS-Service][start] processMessages hasDraft');
//     _isProcessingDraftMessages = true;

//     retryTime++;

//     // Edge Case when database has not updated the new issueID for new comments
//     if (draftMsg.type != CSMessageType.createIssue.rawValue &&
//         draftMsg.issueID.contains('TEMP')) {
//       final newIssueID = tempIssueIDMap[draftMsg.issueID];
//       if (newIssueID != null) {
//         final draftsToUpdate = _draftCustomerSupportStore.getAll().where(
//               (element) => element.issueID == draftMsg.issueID,
//             );
//         for (final draft in draftsToUpdate) {
//           draft.issueID = newIssueID;
//           await _draftCustomerSupportStore.save(draft, draft.hiveId);
//         }
//       } else {
//         if (!draftMsgsRaw.any(
//           (element) =>
//               (element.issueID == draftMsg.issueID) &&
//               (element.uuid != draftMsg.uuid),
//         )) {
//           await _draftCustomerSupportStore.delete(draftMsg.hiveId);
//         } else {
//           sendMessageFail(draftMsg.uuid);
//         }
//       }

//       _isProcessingDraftMessages = false;
//       unawaited(processMessages());
//       return;
//     }

//     // Parse data
//     final data = DraftCustomerSupportData.fromJson(
//       jsonDecode(draftMsg.data) as Map<String, dynamic>,
//     );
//     List<SendAttachment>? sendAttachments;

//     try {
//       if (data.attachments != null) {
//         sendAttachments = await Future.wait(
//           data.attachments!.map((element) async {
//             final file = File(element.path);
//             final bytes = await file.readAsBytes();
//             return SendAttachment(
//               data: base64Encode(bytes),
//               title: element.fileName,
//             );
//           }),
//         );
//       }
//     } on FileSystemException catch (exception) {
//       log.info('[CS-Service] can not find file in draftCustomerSupport');
//       unawaited(Sentry.captureException(exception));

//       // just delete draft because we can not do anything more
//       await _draftCustomerSupportStore.delete(draftMsg.hiveId);
//       unawaited(removeErrorMessage(draftMsg.uuid));
//       _isProcessingDraftMessages = false;
//       log.info(
//         '[CS-Service][end] processMessages delete invalid draftMesssage',
//       );
//       unawaited(processMessages());
//       return;
//     }

//     try {
//       switch (draftMsg.type) {
//         case 'createIssue':
//           final result = await createIssue(
//             draftMsg.reportIssueType,
//             data.text,
//             sendAttachments,
//             title: data.title,
//             mutedText: draftMsg.mutedMessages.split('[SEPARATOR]'),
//             artworkReportID: data.artworkReportID,
//             customTags: [
//               if (data.announcementContentId != null)
//                 'announcement_${data.announcementContentId}',
//             ],
//           );
//           // after send support message, we should also trigger send log from FF device
//           try {
//             final castingDevice =
//                 BluetoothDeviceManager().castingBluetoothDevice;
//             if (castingDevice != null) {
//               await injector<FFBluetoothService>()
//                   .sendLog(castingDevice, data.text);
//               log.info('[CS-Service] send log from FF Device success');
//             }
//           } catch (e) {
//             log.info('[CS-Service] send log from FF Device failed: $e');
//             unawaited(
//               Sentry.captureException('Send log from FF Device failed: $e'),
//             );
//           }
//           tempIssueIDMap[draftMsg.issueID] = result.issueID;
//           await _draftCustomerSupportStore.delete(draftMsg.hiveId);
//           customerSupportUpdate.value =
//               CustomerSupportUpdate(draft: draftMsg, response: result);

//         default:
//           final result =
//               await commentIssue(draftMsg.issueID, data.text, sendAttachments);
//           await _draftCustomerSupportStore.delete(draftMsg.hiveId);
//           customerSupportUpdate.value =
//               CustomerSupportUpdate(draft: draftMsg, response: result);
//       }

//       // Delete logs attachment so it doesn't waste device's storage
//       if (draftMsg.type == CSMessageType.postLogs.rawValue &&
//           data.attachments != null) {
//         log.info('[CS-Service][start] processMessages delete temp logs file');
//         await Future.wait(
//           data.attachments!.map((element) async {
//             final file = File(element.path);
//             unawaited(file.delete());
//           }),
//         );
//       }
//       unawaited(removeErrorMessage(draftMsg.uuid));
//     } catch (exception) {
//       log.info('[CS-Service] not notify to user if there is any error');
//       unawaited(Sentry.captureException(exception));
//     }
//     sendMessageFail(draftMsg.uuid);
//     _isProcessingDraftMessages = false;
//     log.info('[CS-Service][end] processMessages hasDraft');
//     unawaited(processMessages());
//   }

//   @override
//   Future<List<DraftCustomerSupport>> getDrafts(String issueID) async {
//     final results = _draftCustomerSupportStore.getAll().where((element) {
//       return element.issueID == issueID;
//     }).toList();
//     return results;
//   }

//   Future<PostedMessageResponse> createIssue(
//     String reportIssueType,
//     String? message,
//     List<SendAttachment>? attachments, {
//     String? title,
//     List<String>? mutedText,
//     String? artworkReportID,
//     List<String> customTags = const [],
//   }) async {
//     var issueTitle = title ?? message;
//     if (issueTitle == null || issueTitle.isEmpty) {
//       issueTitle = attachments?.first.title ?? 'Unnamed';
//     }

//     // add tags
//     final tags = [...customTags, reportIssueType];
//     if (Platform.isIOS) {
//       tags.add('iOS');
//     } else if (Platform.isAndroid) {
//       tags.add('android');
//     }

//     // Muted Message
//     var mutedMessage = '';
//     final deviceID = await getDeviceID();
//     mutedMessage += '**DeviceID**: $deviceID\n';

//     final version = (await PackageInfo.fromPlatform()).version;
//     mutedMessage += '**Version**: $version\n';

//     final deviceInfo = await DeviceInfo.instance.getUserDeviceInfo();
//     mutedMessage += '**DeviceName**: ${deviceInfo.name}\n';
//     mutedMessage += '**OSVersion**: ${deviceInfo.oSVersion}\n';

//     for (final mutedMsg in mutedText ?? []) {
//       mutedMessage += '$mutedMsg\n';
//     }

//     // add tags to muted message
//     mutedMessage += '**Tags**: ${tags.join(', ')}\n';

//     final submitMessage = "[MUTED]\n$mutedMessage[/MUTED]\n\n${message ?? ''}";

//     final payload = {
//       'attachments': attachments ?? [],
//       'title': issueTitle,
//       'message': submitMessage,
//       'tags': tags,
//     };

//     if (artworkReportID != null && artworkReportID.isNotEmpty) {
//       payload['artwork_report_id'] = artworkReportID;
//     }

//     final userId = await _configurationService.getDeviceId();
//     final issue = await _customerSupportApi.createAnonymousIssue(
//       payload,
//       apiKey: Environment.supportApiKey,
//       deviceId: userId,
//     );
//     await _configurationService.addAnonymousIssueId([issue.issueID]);
//     return issue;
//   }

//   Future<PostedMessageResponse> commentIssue(
//     String issueID,
//     String? message,
//     List<SendAttachment>? attachments,
//   ) async {
//     final payload = {
//       'attachments': attachments ?? [],
//       'message': message ?? '',
//     };

//     return _customerSupportApi.commentIssue(issueID, payload);
//   }

//   @override
//   Future<String> getStoredDirectory() async {
//     final appDocumentsDirectory = await getApplicationDocumentsDirectory();
//     final appDocumentsPath = appDocumentsDirectory.path;
//     return '$appDocumentsPath/customer-support';
//   }

//   @override
//   Future<String> storeFile(String filename, List<int> bytes) async {
//     log.info('[start] storeFile $filename');
//     final directory = await getStoredDirectory();
//     final filePath = '$directory/$filename'; // 3

//     final file = File(filePath);
//     await file.create(recursive: true);
//     await file.writeAsBytes(bytes, flush: true);
//     log.info('[done] storeFile $filename');
//     return file.path;
//   }

//   @override
//   Future<void> reopen(String issueID) async =>
//       _customerSupportApi.reOpenIssue(issueID);

//   @override
//   Future<void> rateIssue(String issueID, int rating) async =>
//       _customerSupportApi.rateIssue(issueID, rating);

//   @override
//   Future<void> clear() async {
//     await _draftCustomerSupportStore.clear();
//   }
// }
