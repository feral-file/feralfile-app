//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: unused_field, type_literal_in_constant_pattern

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/announcement/announcement.dart';
import 'package:autonomy_flutter/model/customer_support.dart' as app;
import 'package:autonomy_flutter/model/customer_support.dart';
import 'package:autonomy_flutter/model/draft_customer_support.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/service/feralfile_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/app_theme.dart';
import 'package:autonomy_flutter/theme/extensions/button_style_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/datetime_ext.dart';
import 'package:autonomy_flutter/util/jwt.dart';
import 'package:autonomy_flutter/util/log.dart' as log_util;
import 'package:autonomy_flutter/util/native_log_reader.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:bubble/bubble.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

abstract class SupportThreadPayload {
  String? get defaultMessage;

  String get introMessage;
}

class NewIssuePayload extends SupportThreadPayload {
  NewIssuePayload({
    required this.reportIssueType,
    this.artworkReportID,
    this.defaultMessage,
  });

  final String reportIssueType;
  final String? artworkReportID;
  @override
  final String? defaultMessage;

  @override
  String get introMessage => ReportIssueType.introMessage(reportIssueType);
}

class NewIssueFromAnnouncementPayload extends SupportThreadPayload {
  NewIssueFromAnnouncementPayload({
    required this.announcement,
    this.defaultMessage,
    this.title,
  });

  final Announcement announcement;
  final String? title;

  @override
  final String? defaultMessage;

  @override
  // TODO: implement introMessage
  String get introMessage => announcement.content;
}

class DetailIssuePayload extends SupportThreadPayload {
  DetailIssuePayload({
    required this.reportIssueType,
    required this.issueID,
    this.defaultMessage,
    this.status = '',
    this.isRated = false,
  });

  final String reportIssueType;
  final String issueID;
  final String status;
  final bool isRated;
  @override
  final String? defaultMessage;

  @override
  String get introMessage {
    final announcement =
        injector<AnnouncementService>().findAnnouncementByIssueId(issueID);
    if (announcement != null) {
      return announcement.content;
    }
    return ReportIssueType.introMessage(reportIssueType);
  }
}

class ExceptionErrorPayload extends SupportThreadPayload {
  ExceptionErrorPayload({
    required this.sentryID,
    required this.metadata,
    this.defaultMessage,
  });

  final String sentryID;
  final String metadata;
  @override
  final String? defaultMessage;

  @override
  String get introMessage =>
      ReportIssueType.introMessage(ReportIssueType.Exception);
}

class SupportThreadPage extends StatefulWidget {
  const SupportThreadPage({
    required this.payload,
    super.key,
  });

  final SupportThreadPayload payload;

  @override
  State<SupportThreadPage> createState() => _SupportThreadPageState();
}

class _SupportThreadPageState extends State<SupportThreadPage> {
  String _reportIssueType = '';
  String? _issueID;

  List<types.Message> _messages = [];
  List<types.Message> _draftMessages = [];
  final _user = const types.User(id: 'user');
  final _bitmark = const types.User(id: 'bitmark');

  String _status = '';
  bool _isRated = false;
  bool _isFileAttached = false;
  List<Pair<String, List<int>>> _debugLogs = [];
  late TextEditingController _textEditingController;

  late Object _forceAccountsViewRedraw;
  var _sendIcon = 'assets/images/sendMessage.svg';
  final _introMessengerID = const Uuid().v4();
  final _resolvedMessengerID = const Uuid().v4();
  final _askRatingMessengerID = const Uuid().v4();
  final _askReviewMessengerID = const Uuid().v4();
  final _announcementMessengerID = const Uuid().v4();
  final _customerSupportService = injector<CustomerSupportService>();
  final _feralFileService = injector<FeralFileService>();

  String? _userId;
  Announcement? _announcement;

  types.TextMessage get _introMessenger => types.TextMessage(
        author: _bitmark,
        id: _introMessengerID,
        text: widget.payload.introMessage,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  types.CustomMessage get _resolvedMessenger => types.CustomMessage(
        id: _resolvedMessengerID,
        author: _bitmark,
        metadata: const {'status': 'resolved'},
      );

  types.CustomMessage get _askRatingMessenger => types.CustomMessage(
        author: _bitmark,
        id: _askRatingMessengerID,
        metadata: {'status': 'rateIssue', 'content': 'rate_issue'.tr()},
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  void _setIssueId(String issueId) {
    _issueID = issueId;
    _announcement =
        injector<AnnouncementService>().findAnnouncementByIssueId(issueId);
  }

  @override
  void initState() {
    unawaited(injector<CustomerSupportService>().processMessages());
    injector<CustomerSupportService>()
        .triggerReloadMessages
        .addListener(_loadIssueDetails);

    _customerSupportService.customerSupportUpdate
        .addListener(_loadCustomerSupportUpdates);

    final payload = widget.payload;
    switch (payload.runtimeType) {
      case NewIssuePayload:
        _reportIssueType = (payload as NewIssuePayload).reportIssueType;
        if (_reportIssueType == ReportIssueType.Bug &&
            (payload.defaultMessage?.isEmpty ?? true) &&
            (payload.artworkReportID?.isEmpty ?? true)) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) {
              return;
            }
            _askForAttachCrashLog(
              context,
              onConfirm: (attachCrashLog) {
                if (attachCrashLog) {
                  unawaited(_addDebugLog());
                } else {
                  UIHelper.hideInfoDialog(context);
                }
              },
            );
          });
        }
      case NewIssueFromAnnouncementPayload:
        _reportIssueType = ReportIssueType.ChatWithFeralfile;
      case DetailIssuePayload:
        _reportIssueType = (payload as DetailIssuePayload).reportIssueType;
        _status = payload.status;
        _isRated = payload.isRated;
        // if the issue is already created, we need to set the issueID
        final issueID =
            _customerSupportService.tempIssueIDMap[payload.issueID] ??
                payload.issueID;
        _setIssueId(issueID);
        unawaited(_getUserId(issueID));
      case ExceptionErrorPayload:
        _reportIssueType = ReportIssueType.Exception;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) {
            return;
          }
          _askForAttachCrashLog(
            context,
            onConfirm: (attachCrashLog) {
              if (attachCrashLog) {
                unawaited(_addDebugLog());
              } else {
                UIHelper.hideInfoDialog(context);
              }
            },
          );
        });
    }

    _textEditingController =
        TextEditingController(text: widget.payload.defaultMessage);

    memoryValues.viewingSupportThreadIssueID = _issueID;
    _forceAccountsViewRedraw = Object();
    super.initState();

    unawaited(_loadDrafts());

    if (_issueID != null && !_issueID!.startsWith('TEMP')) {
      unawaited(_loadIssueDetails());
    }
    _markAnnouncementAsRead();
  }

  void _markAnnouncementAsRead() {
    if (widget.payload is NewIssueFromAnnouncementPayload) {
      final announcement =
          (widget.payload as NewIssueFromAnnouncementPayload).announcement;
      unawaited(
        injector<AnnouncementService>()
            .markAsRead(announcement.announcementContentId),
      );
    }
  }

  Future<void> _getUserId(String issueId) async {
    // if userId is already set, we don't need to get the userId
    if (_userId != null) {
      return;
    }
    // if it is an anonymous issue, we need to get the anonymous device id
    final configurationService = injector<ConfigurationService>();
    final anonymousIssueIds = configurationService.getAnonymousIssueIds();

    if (anonymousIssueIds.contains(issueId)) {
      _userId = configurationService.getAnonymousDeviceId();
      return;
    }

    // if it is a normal issue, we need to get the userId
    final jwt = await injector<AuthService>().getAuthToken();
    if (jwt != null) {
      final data = parseJwt(jwt.jwtToken);
      final sub = data['sub'] as String;
      if (sub != _userId) {
        if (mounted) {
          setState(() {
            _userId = sub;
          });
        }
      }
    }
  }

  Future<void> _addDebugLog() async {
    Navigator.of(context).pop();

    const fileMaxSize = 1024 * 1024;

    _debugLogs.clear();

    // Lấy native log
    try {
      if (Platform.isAndroid) {
        final nativeLogContent = await NativeLogReader.getLogContent();
        final nativeLogBytes = utf8.encode(nativeLogContent);
        var nativeLogCombinedBytes = nativeLogBytes;
        if (nativeLogCombinedBytes.length > fileMaxSize) {
          nativeLogCombinedBytes = nativeLogCombinedBytes
              .sublist(nativeLogCombinedBytes.length - fileMaxSize);
        }
        final nativeLogFilename =
            'native_${nativeLogCombinedBytes.length}_${DateTime.now().microsecondsSinceEpoch}.logs';
        _debugLogs.add(Pair(nativeLogFilename, nativeLogCombinedBytes));
      }
    } catch (e) {
      log_util.log.severe('Failed to get native log: $e');
    }

    try {
      final file = await log_util.getLogFile();
      final bytes = await file.readAsBytes();
      var combinedBytes = bytes;
      if (combinedBytes.length > fileMaxSize) {
        combinedBytes =
            combinedBytes.sublist(combinedBytes.length - fileMaxSize);
      }
      final filename =
          'flutter_${combinedBytes.length}_${DateTime.now().microsecondsSinceEpoch}.logs';
      _debugLogs.add(Pair(filename, combinedBytes));
    } catch (e) {
      log_util.log.severe('Failed to get Flutter log: $e');
    }

    setState(() {
      _isFileAttached = _debugLogs.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _customerSupportService.triggerReloadMessages
        .removeListener(_loadIssueDetails);
    _customerSupportService.customerSupportUpdate
        .removeListener(_loadCustomerSupportUpdates);

    memoryValues.viewingSupportThreadIssueID = null;
    super.dispose();
  }

  void _askForAttachCrashLog(
    BuildContext context, {
    required void Function(bool attachCrashLog) onConfirm,
  }) {
    final theme = Theme.of(context);
    unawaited(
      UIHelper.showDialog(
        context,
        'attach_crash_log'.tr(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ask_attach_crash'.tr(),
              style: theme.primaryTextTheme.ppMori400White14,
            ),
            const SizedBox(height: 40),
            PrimaryButton(
              text: 'attach_crash_logH'.tr(),
              onTap: () => onConfirm(true),
            ),
            const SizedBox(height: 10),
            OutlineButton(
              text: 'conti_no_crash_log'.tr(),
              onTap: () => onConfirm(false),
            ),
            const SizedBox(height: 40),
          ],
        ),
        isDismissible: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<types.Message> messages = _draftMessages + _messages;
    ////// this convert rating messages to customMessage type, then convert the string messages to rating bars
    if (messages.isNotEmpty) {
      for (int i = 0; i < messages.length; i++) {
        if (_isRating(messages[i])) {
          final ratingMessengerID = const Uuid().v4();
          final ratingMessenger = types.CustomMessage(
            id: ratingMessengerID,
            author: _user,
            metadata: {
              'status': 'rating',
              'rating': messages[i].metadata!['rating'],
            },
          );
          messages[i] = ratingMessenger;
        }
      }

      messages.removeWhere(
        (element) =>
            messages.indexOf(element) != 0 && _isRatingMessage(element),
      );

      if (_status == 'closed' || _status == 'clickToReopen') {
        final ratingIndex =
            messages.indexWhere((element) => _isRatingMessage(element));
        if (messages[ratingIndex + 1] != _askRatingMessenger) {
          messages
            ..insert(ratingIndex + 1, _resolvedMessenger)
            ..insert(ratingIndex + 1, _askRatingMessenger);
        }
      }
    }

    if (_issueID == null || messages.isNotEmpty) {
      messages.add(_introMessenger);
    }

    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: ReportIssueType.toTitle(_reportIssueType),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Container(
        margin: EdgeInsets.zero,
        child: Chat(
          l10n: ChatL10nEn(
            inputPlaceholder: 'write_message'.tr(),
          ),
          customDateHeaderText: getChatDateTimeRepresentation,
          bubbleBuilder: _bubbleBuilder,
          theme: _chatTheme,
          customMessageBuilder: _customMessageBuilder,
          emptyState: const CupertinoActivityIndicator(),
          messages: messages.map((e) {
            if (e is types.TextMessage &&
                e.text.startsWith(RATING_MESSAGE_START)) {
              return e.copyWith(
                text: e.text.substring(RATING_MESSAGE_START.length),
              );
            }
            return e;
          }).toList(),
          onSendPressed: _handleSendPressed,
          user: _user,
          customBottomWidget: _status == 'closed'
              ? _isRated
                  ? const SizedBox()
                  : MyRatingBar(
                      submit: (
                        String messageType,
                        DraftCustomerSupportData data, {
                        bool isRating = false,
                      }) =>
                          // ignore: discarded_futures
                          _submit(messageType, data, isRating: isRating),
                    )
              : Column(
                  children: [
                    if (_isFileAttached) debugLogView(),
                    Input(
                      onSendPressed: _handleSendPressed,
                      onAttachmentPressed: _handleAttachmentPressed,
                      options: _inputOption(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  InputOptions _inputOption() => InputOptions(
        sendButtonVisibilityMode: SendButtonVisibilityMode.always,
        onTextChanged: (text) {
          if (_sendIcon == 'assets/images/sendMessageFilled.svg' &&
                  text.trim() == '' ||
              _sendIcon == 'assets/images/sendMessage.svg' &&
                  text.trim() != '') {
            setState(() {
              _sendIcon = text.trim() != ''
                  ? 'assets/images/sendMessageFilled.svg'
                  : 'assets/images/sendMessage.svg';
            });
          }
        },
        textEditingController: _textEditingController,
      );

  Widget debugLogView() {
    if (_debugLogs.isEmpty) {
      return const SizedBox();
    }
    final theme = Theme.of(context);
    return Column(
      children: _debugLogs.map((debugLog) {
        final fileSize = debugLog.second.length;
        final fileSizeInMB = fileSize / (1024 * 1024);
        return Container(
          color: AppColor.auGreyBackground,
          padding: const EdgeInsets.fromLTRB(25, 5, 25, 5),
          child: Row(
            children: [
              Text(
                debugLog.first.split('_').last,
                style: theme.primaryTextTheme.ppMori400White14
                    .copyWith(color: AppColor.feralFileHighlight),
              ),
              const SizedBox(width: 5),
              Text(
                '(${fileSizeInMB.toStringAsFixed(2)} MB)',
                style: theme.primaryTextTheme.ppMori400White14
                    .copyWith(color: AppColor.auQuickSilver),
              ),
              const Spacer(),
              Semantics(
                label: 'Remove debug log',
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _debugLogs.remove(debugLog);
                      _isFileAttached = _debugLogs.isNotEmpty;
                    });
                  },
                  child: SvgPicture.asset(
                    'assets/images/iconClose.svg',
                    width: 20,
                    height: 20,
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _isRatingMessage(types.Message message) {
    if (message is types.CustomMessage) {
      if (message.metadata?['rating'] == null) {
        return false;
      }
      if ((message.metadata?['rating'] as int? ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  Widget _ratingBar(int rating) {
    if (rating == 0) {
      return const SizedBox();
    }
    return RatingBar.builder(
      initialRating: rating.toDouble(),
      minRating: 1,
      itemSize: 24,
      itemPadding: const EdgeInsets.symmetric(horizontal: 10),
      itemBuilder: (context, _) => const Icon(
        Icons.star,
        color: AppColor.white,
      ),
      unratedColor: AppColor.secondarySpanishGrey,
      ignoreGestures: true,
      onRatingUpdate: (double value) {},
    );
  }

  Widget _bubbleBuilder(
    Widget child, {
    required types.Message message,
    required bool nextMessageInGroup,
  }) {
    final theme = Theme.of(context);
    var color = _user.id != message.author.id
        ? AppColor.feralFileHighlight
        : AppColor.primaryBlack;

    if (message.type == types.MessageType.image) {
      color = Colors.transparent;
    }
    bool isError = false;
    String uuid = '';
    if (message.status == types.Status.error) {
      isError = true;
      uuid = message.id;
    }
    Color orangeRust = const Color(0xffA1200A);

    return isError
        ? Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Bubble(
                        color: color,
                        radius: const Radius.circular(10),
                        nipWidth: 0.1,
                        nipRadius: 0,
                        nip: _user.id != message.author.id
                            ? BubbleNip.leftBottom
                            : BubbleNip.rightBottom,
                        child: child,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await _customerSupportService.removeErrorMessage(uuid);
                        unawaited(_loadDrafts());
                        unawaited(_customerSupportService.processMessages());
                        Future.delayed(const Duration(seconds: 5), () {
                          _loadDrafts();
                        });
                      },
                      child: Text(
                        'retry'.tr(),
                        style: theme.textTheme.ppMori400Black12.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: AppColor.primaryBlack,
                        ),
                      ),
                    ),
                    Text(
                      '・',
                      style: theme.textTheme.ppMori400Black12,
                    ),
                    GestureDetector(
                      onTap: () async {
                        await _customerSupportService.removeErrorMessage(
                          uuid,
                          isDelete: true,
                        );
                        await _loadDrafts();
                        if (_draftMessages.isEmpty && _messages.isEmpty) {
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        'delete'.tr(),
                        style: theme.textTheme.ppMori400Black12.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: AppColor.primaryBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'failed_to_send'.tr(),
                      style: theme.textTheme.ppMori400Black12
                          .copyWith(color: orangeRust),
                    ),
                  ],
                ),
              ],
            ),
          )
        : Bubble(
            color: color,
            radius: const Radius.circular(10),
            nipWidth: 0.1,
            nipRadius: 0,
            nip: _user.id != message.author.id
                ? BubbleNip.leftBottom
                : BubbleNip.rightBottom,
            child: child,
          );
  }

  Widget _customMessageBuilder(
    types.CustomMessage message, {
    required int messageWidth,
  }) {
    final theme = Theme.of(context);
    switch (message.metadata?['status']) {
      case 'resolved':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: AppColor.feralFileHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'issue_resolved_'.tr(),
                textAlign: TextAlign.start,
                style: ResponsiveLayout.isMobile
                    ? theme.textTheme.ppMori700Black14
                    : theme.textTheme.ppMori700Black16,
              ),
              const SizedBox(height: 10),
              Text(
                'our_team_thank'.tr(),
                textAlign: TextAlign.start,
                style: ResponsiveLayout.isMobile
                    ? theme.textTheme.ppMori400Black14
                    : theme.textTheme.ppMori400Black16,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  if (_status == 'closed') {
                    setState(() {
                      _status = 'clickToReopen';
                    });
                  }
                },
                style: theme.textButtonNoPadding,
                child: Text(
                  'still_problem'.tr(),
                  //"Still experiencing the same problem?",
                  style: ResponsiveLayout.isMobile
                      ? theme.textTheme.linkStyle14
                          .copyWith(fontFamily: AppTheme.ppMori)
                      : theme.textTheme.linkStyle16
                          .copyWith(fontFamily: AppTheme.ppMori),
                ),
              ),
            ],
          ),
        );
      case 'rating':
        final rating = message.metadata?['rating'] as int? ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: AppColor.primaryBlack,
          child: _ratingBar(rating),
        );
      case 'careToShare':
      case 'rateIssue':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          color: AppColor.feralFileHighlight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.metadata?['content'] as String,
                textAlign: TextAlign.start,
                style: ResponsiveLayout.isMobile
                    ? theme.textTheme.ppMori700Black14
                    : theme.textTheme.ppMori700Black16,
              ),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  Future<void> _loadIssueDetails() async {
    if (_issueID == null) {
      return;
    }
    final issueDetails = await _customerSupportService.getDetails(_issueID!);
    if (issueDetails.issue.userId != null) {
      _userId = issueDetails.issue.userId;
    }
    final parsedMessages = (await Future.wait(
      issueDetails.messages.map((e) => _convertChatMessage(e, null)),
    ))
        .expand((i) => i)
        .toList();

    if (mounted) {
      setState(() {
        String lastMessage = '';
        if (issueDetails.messages.isNotEmpty) {
          lastMessage = issueDetails.messages[0].message;
        }

        _status = issueDetails.issue.status;
        _isRated = issueDetails.issue.rating > 0 &&
            issueDetails.issue.status == 'closed' &&
            (lastMessage.contains(RATING_MESSAGE_START) ||
                lastMessage.contains(STAR_RATING));
        _reportIssueType = issueDetails.issue.reportIssueType;
        _messages = parsedMessages;
      });
    }
  }

  bool _isRating(types.Message message) {
    final rating = message.metadata?['rating'] as int?;
    if (rating != null && rating > 0 && rating < 6) {
      return true;
    }
    return false;
  }

  Future<void> _loadDrafts() async {
    if (_issueID == null) {
      return;
    }
    final drafts = await _customerSupportService.getDrafts(_issueID!);
    final draftMessages =
        (await Future.wait(drafts.map((e) => _convertChatMessage(e, null))))
            .expand((i) => i)
            .toList();
    if (mounted) {
      setState(() {
        _draftMessages = draftMessages;
      });
    }
  }

  Future<void> _loadCustomerSupportUpdates() async {
    final update = _customerSupportService.customerSupportUpdate.value;
    if (update == null) {
      return;
    }
    if (update.draft.issueID != _issueID) {
      return;
    }
    // when user create a new issue, we need to update the issueID
    _setIssueId(update.response.issueID);
    await _getUserId(update.response.issueID);
    memoryValues.viewingSupportThreadIssueID = _issueID;
    final newMessages =
        await _convertChatMessage(update.response.message, update.draft.uuid);

    setState(() {
      _draftMessages
          .removeWhere((element) => element.id.startsWith(update.draft.uuid));
      _messages.insertAll(0, newMessages);
    });
  }

  Future<void> _submit(
    String messageType,
    DraftCustomerSupportData data, {
    bool isRating = false,
  }) async {
    log_util.log.info('[CS-Thread][start] _submit $messageType - $data');
    List<String> mutedMessages = [];
    if (_issueID == null) {
      messageType = CSMessageType.createIssue.rawValue;
      _issueID = 'TEMP-${const Uuid().v4()}';

      final payload = widget.payload;
      switch (payload.runtimeType) {
        case ExceptionErrorPayload:
          final sentryID = (payload as ExceptionErrorPayload).sentryID;
          if (sentryID.isNotEmpty) {
            mutedMessages.add(
              '[SENTRY REPORT $sentryID](https://sentry.io/organizations/bitmark-inc/issues/?query=$sentryID)',
            );
          }

          if (payload.metadata.isNotEmpty) {
            mutedMessages.add('METADATA EXCEPTION: ${payload.metadata}');
          }
        case NewIssuePayload:
          if (payload.defaultMessage != null &&
              payload.defaultMessage!.isNotEmpty) {
            data.artworkReportID = (payload as NewIssuePayload).artworkReportID;
          }
        case NewIssueFromAnnouncementPayload:
          data.announcementContentId =
              (payload as NewIssueFromAnnouncementPayload)
                  .announcement
                  .announcementContentId;
      }
    }
    if (isRating) {
      mutedMessages.add(MUTE_RATING_MESSAGE);
    }

    if (messageType == CSMessageType.postMessage.rawValue &&
        _isRated &&
        _status == 'closed') {
      data.text = '$RATING_MESSAGE_START${data.text}';
    }

    final draft = DraftCustomerSupport(
      uuid: const Uuid().v4(),
      issueID: _issueID!,
      type: messageType,
      data: json.encode(data),
      createdAt: DateTime.now(),
      reportIssueType: _reportIssueType,
      mutedMessages: mutedMessages.join('[SEPARATOR]'),
    );

    _draftMessages.insertAll(0, await _convertChatMessage(draft, null));

    if (_issueID != null && _status == 'clickToReopen') {
      setState(() {
        _status = 'reopening';
      });
      await _customerSupportService.reopen(_issueID!);
      _status = 'open';
      _isRated = false;
    }

    await _customerSupportService.draftMessage(draft);
    if (isRating) {
      final rating = getRating(data.text ?? '');
      if (rating > 0) {
        await _customerSupportService.rateIssue(_issueID!, rating);
      }
    }
    setState(() {
      _sendIcon = 'assets/images/sendMessage.svg';
      _forceAccountsViewRedraw = Object();
      if (isRating) {
        _isRated = true;
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      _loadDrafts();
    });
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    if (_isFileAttached) {
      await _addAppLogs(message);
    } else {
      await _submit(
        CSMessageType.postMessage.rawValue,
        DraftCustomerSupportData(text: message.text),
      );
    }
  }

  Future<void> _addAppLogs(types.PartialText message) async {
    if (_debugLogs.isEmpty) {
      return;
    }

    final attachments = await Future.wait(
      _debugLogs.map((debugLog) async {
        final filename = debugLog.first;
        final combinedBytes = debugLog.second;
        final localPath =
            await _customerSupportService.storeFile(filename, combinedBytes);
        return LocalAttachment(fileName: filename, path: localPath);
      }),
    );

    await _submit(
      CSMessageType.postLogs.rawValue,
      DraftCustomerSupportData(
        text: message.text,
        attachments: attachments,
      ),
    );
    setState(() {
      _isFileAttached = false;
      _debugLogs.clear();
    });
  }

  void _handleAttachmentPressed() {
    if (_isFileAttached) {
      return;
    }
    unawaited(
      UIHelper.showDialog(
        context,
        'attach_file'.tr(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryButton(
              onTap: () {
                _handleImageSelection();
                Navigator.of(context).pop();
              },
              text: 'photo'.tr(),
            ),
            const SizedBox(
              height: 10,
            ),
            PrimaryButton(
              onTap: () async {
                await _addDebugLog();
              },
              text: 'debug_log'.tr(),
            ),
            const SizedBox(height: 10),
            OutlineButton(
              onTap: () => Navigator.of(context).pop(),
              text: 'cancel_dialog'.tr(),
            ),
            const SizedBox(height: 15),
          ],
        ),
        isDismissible: true,
      ),
    );
  }

  Future<void> _handleImageSelection() async {
    log_util.log.info('[_handleImageSelection] begin');
    final result = await ImagePicker().pickMultiImage();

    final attachments = await Future.wait(
      result.map((element) async {
        final bytes = await element.readAsBytes();
        final fileName = '${bytes.length}_${element.name}';
        final localPath =
            await _customerSupportService.storeFile(fileName, bytes);
        return LocalAttachment(path: localPath, fileName: fileName);
      }),
    );

    await _submit(
      CSMessageType.postPhotos.rawValue,
      DraftCustomerSupportData(attachments: attachments),
    );
  }

  Future<List<types.Message>> _convertChatMessage(
    dynamic message,
    String? tempID,
  ) async {
    String id;
    types.User author;
    types.Status status;
    DateTime createdAt;
    String? text;
    int rating = 0;
    Map<String, dynamic> metadata = {};
    if (message is app.Message) {
      id = tempID ?? '${message.id}';
      author = (message.from == _userId || message.from.contains('did:key'))
          ? _user
          : _bitmark;
      status = types.Status.delivered;
      createdAt = message.timestamp;
      text = message.filteredMessage;
      rating = getRating(text);
      if (rating > 0) {
        metadata = {'rating': rating};
      }
      //
    } else if (message is DraftCustomerSupport) {
      id = message.uuid;
      author = _user;
      final errorMessages = _customerSupportService.errorMessages;
      status = (errorMessages != null && errorMessages.contains(id))
          ? types.Status.error
          : types.Status.sending;
      createdAt = message.createdAt;
      text = message.draftData.text;
      metadata = Map<String, dynamic>.from(json.decode(message.data) as Map);
      rating = message.draftData.rating;
      if (rating > 0) {
        metadata['rating'] = rating;
      }
      //
    } else {
      return [];
    }

    List<types.Message> result = [];

    if (text is String && text.isNotEmpty && text != EMPTY_ISSUE_MESSAGE) {
      result.add(
        types.TextMessage(
          id: id,
          author: author,
          createdAt: createdAt.millisecondsSinceEpoch,
          text: text,
          status: status,
          showStatus: true,
          metadata: metadata,
        ),
      );
    }

    final storedDirectory = await _customerSupportService.getStoredDirectory();
    List<String> titles = [];
    List<String> uris = [];
    List<String> contentTypes = [];

    if (message is app.Message) {
      for (var attachment in message.attachments) {
        titles.add(attachment.title);
        uris.add('$storedDirectory/${attachment.title}');
        contentTypes.add(attachment.contentType);
      }
      //
    } else if (message is DraftCustomerSupport) {
      for (final attachment
          in message.draftData.attachments ?? <LocalAttachment>[]) {
        titles.add(attachment.fileName);
        uris.add(attachment.path);
        contentTypes.add(
          message.type == CSMessageType.postPhotos.rawValue ? 'image' : 'logs',
        );
      }
    }

    for (var i = 0; i < titles.length; i += 1) {
      if (contentTypes[i].contains('image')) {
        result.add(
          types.ImageMessage(
            id: '$id${titles[i]}',
            author: author,
            createdAt: createdAt.millisecondsSinceEpoch,
            status: status,
            showStatus: true,
            name: titles[i],
            size: 0,
            uri: uris[i],
          ),
        );
      } else {
        final sizeAndRealTitle =
            ReceiveAttachment.extractSizeAndRealTitle(titles[i]);
        final title = sizeAndRealTitle[1] as String;
        final size = int.tryParse(sizeAndRealTitle[0].toString()) ?? 0;
        result.insert(
          0,
          types.FileMessage(
            id: '$id${sizeAndRealTitle[1]}',
            author: author,
            createdAt: createdAt.millisecondsSinceEpoch,
            status: status,
            showStatus: true,
            name: title,
            size: size,
            uri: uris[i],
          ),
        );
      }
    }

    return result;
  }

  int getRating(String text) {
    if (text.startsWith(STAR_RATING)) {
      final rating = int.tryParse(text.replacePrefix(STAR_RATING, ''));
      if (rating != null && rating > 0 && rating <= 5) {
        return rating;
      }
    }
    return 0;
  }

  DefaultChatTheme get _chatTheme {
    final theme = Theme.of(context);
    bool isKeyboardShowing = MediaQuery.of(context).viewInsets.vertical > 0;
    final inputPadding = isKeyboardShowing
        ? const EdgeInsets.fromLTRB(0, 20, 0, 20)
        : const EdgeInsets.fromLTRB(0, 10, 0, 32);
    return DefaultChatTheme(
      messageInsetsVertical: 14,
      messageInsetsHorizontal: 14,
      errorIcon: const SizedBox(),
      inputPadding: inputPadding,
      backgroundColor: Colors.transparent,
      inputBackgroundColor: theme.colorScheme.primary,
      inputTextStyle: theme.textTheme.ppMori400White14,
      inputTextColor: theme.colorScheme.secondary,
      attachmentButtonIcon: Semantics(
        label: 'Attach file',
        child: SvgPicture.asset(
          'assets/images/joinFile.svg',
          colorFilter: ColorFilter.mode(
            _isFileAttached
                ? AppColor.disabledColor
                : theme.colorScheme.secondary,
            BlendMode.srcIn,
          ),
        ),
      ),
      inputBorderRadius: BorderRadius.zero,
      sendButtonIcon: SvgPicture.asset(
        _sendIcon,
      ),
      inputTextCursorColor: theme.colorScheme.secondary,
      emptyChatPlaceholderTextStyle: theme.textTheme.ppMori400White14
          .copyWith(color: AppColor.auQuickSilver),
      dateDividerMargin: const EdgeInsets.symmetric(vertical: 12),
      dateDividerTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.dateDividerTextStyle
          : theme.textTheme.dateDividerTextStyle14,
      primaryColor: Colors.transparent,
      sentMessageBodyTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.sentMessageBodyTextStyle
          : theme.textTheme.sentMessageBodyTextStyle16,
      secondaryColor: AppColor.chatSecondaryColor,
      receivedMessageBodyTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.receivedMessageBodyTextStyle
          : theme.textTheme.receivedMessageBodyTextStyle16,
      receivedMessageDocumentIconColor: Colors.transparent,
      sentMessageDocumentIconColor: Colors.transparent,
      documentIcon: SvgPicture.asset(
        'assets/images/bug_icon.svg',
        width: 20,
      ),
      sentMessageCaptionTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.sentMessageCaptionTextStyle
          : theme.textTheme.sentMessageCaptionTextStyle16,
      receivedMessageCaptionTextStyle: ResponsiveLayout.isMobile
          ? theme.textTheme.receivedMessageCaptionTextStyle
          : theme.textTheme.receivedMessageCaptionTextStyle16,
      sendingIcon: Container(
        width: 16,
        height: 12,
        padding: const EdgeInsets.only(left: 3),
        child: const CircularProgressIndicator(
          color: AppColor.secondarySpanishGrey,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class MyRatingBar extends StatefulWidget {
  const MyRatingBar({required this.submit, super.key});

  final Future<dynamic> Function(
    String messageType,
    DraftCustomerSupportData data, {
    bool isRating,
  }) submit;

  @override
  State<MyRatingBar> createState() => _MyRatingBarState();
}

class _MyRatingBarState extends State<MyRatingBar> {
  String customerRating = '';
  int ratingInt = 0;
  Widget sendButtonRating = SvgPicture.asset('assets/images/sendMessage.svg');

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 30),
        color: AppColor.primaryBlack,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RatingBar.builder(
              minRating: 1,
              itemSize: 24,
              itemPadding: const EdgeInsets.symmetric(horizontal: 10),
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: AppColor.white,
              ),
              unratedColor: AppColor.chatSecondaryColor,
              onRatingUpdate: _updateRating,
            ),
            const SizedBox(width: 40),
            IconButton(onPressed: _sendButtonOnPress, icon: sendButtonRating),
            const SizedBox(width: 10),
          ],
        ),
      );

  void _updateRating(double rating) {
    ratingInt = rating.toInt();
    customerRating = _convertRatingToText(ratingInt);
    setState(() {
      sendButtonRating =
          SvgPicture.asset('assets/images/sendMessageFilled.svg');
    });
  }

  Future<void> _sendButtonOnPress() async {
    if (ratingInt < 1) {
      return;
    }
    await widget.submit(
      CSMessageType.postMessage.rawValue,
      DraftCustomerSupportData(text: customerRating, rating: ratingInt),
      isRating: true,
    );
  }

  String _convertRatingToText(int rating) {
    if (rating > 0) {
      return '$STAR_RATING$rating';
    }

    return '';
  }
}
