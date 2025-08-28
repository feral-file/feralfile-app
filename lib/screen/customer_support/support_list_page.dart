//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:math';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/announcement/announcement.dart';
import 'package:autonomy_flutter/model/announcement/announcement_local.dart';
import 'package:autonomy_flutter/model/customer_support.dart';
import 'package:autonomy_flutter/model/draft_customer_support.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/service/customer_support_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/datetime_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SupportListPage extends StatefulWidget {
  const SupportListPage({super.key});

  @override
  State<SupportListPage> createState() => _SupportListPageState();
}

class _SupportListPageState extends State<SupportListPage>
    with RouteAware, WidgetsBindingObserver {
  List<ChatThread>? _chatThreads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    unawaited(loadIssues());
    injector<CustomerSupportService>()
        .triggerReloadMessages
        .addListener(loadIssues);
  }

  @override
  void didPopNext() {
    unawaited(loadIssues());
    super.didPopNext();
  }

  @override
  void dispose() {
    super.dispose();
    routeObserver.unsubscribe(this);
    injector<CustomerSupportService>()
        .triggerReloadMessages
        .removeListener(loadIssues);
  }

  Future<List<ChatThread>> _loadChatThreads() async {
    final chatThreads =
        await injector<CustomerSupportService>().getChatThreads();
    return chatThreads;
  }

  Future<void> loadIssues() async {
    final chatThreads = await _loadChatThreads();
    if (mounted) {
      setState(() {
        _chatThreads = chatThreads;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getBackAppBar(
          context,
          title: 'support_history'.tr(),
          onBack: () => Navigator.of(context).pop(),
        ),
        body: _chatThreadWidget(),
      );

  Widget _chatThreadWidget() {
    final chatThreads = _chatThreads;
    if (chatThreads == null) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (chatThreads.isEmpty) {
      return const SizedBox();
    }

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: addTitleSpace(),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            bool hasDivider = index < chatThreads.length - 1;
            final chatThread = chatThreads[index];
            switch (chatThread.runtimeType) {
              case Issue:
                final issue = chatThread as Issue;
                final status = issue.status;
                final lastMessage =
                    _getDisplayMessage(issue, issue.lastMessage);
                final isRated = (lastMessage.contains(STAR_RATING) ||
                        lastMessage.contains(RATING_MESSAGE_START)) &&
                    issue.rating > 0;
                bool hasDivider = index < chatThreads.length - 1;
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.pageEdgeInsets.left),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    child: _contentRow(issue, hasDivider),
                    onTap: () => unawaited(Navigator.of(context).pushNamed(
                      AppRouter.supportThreadPage,
                      arguments: DetailIssuePayload(
                        reportIssueType: issue.reportIssueType,
                        issueID: issue.issueID,
                        status: status,
                        isRated: isRated,
                      ),
                    )),
                  ),
                );
              case AnnouncementLocal:
              case Announcement:
                final issue = chatThread as Announcement;
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.pageEdgeInsets.left),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    child: _announcementRow(issue, hasDivider),
                    onTap: () => unawaited(Navigator.of(context).pushNamed(
                      AppRouter.supportThreadPage,
                      arguments:
                          NewIssueFromAnnouncementPayload(announcement: issue),
                    )),
                  ),
                );
              default:
                return const SizedBox();
            }
          },
          childCount: chatThreads.length,
        ),
      ),
    ]);
  }

  Widget _contentRow(Issue issue, bool hasDivider) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  issue.getListTitle(),
                  style: theme.textTheme.ppMori400Black16,
                ),
                if (issue.unread > 0) ...[
                  _unreadChatThreadWidget(),
                ]
              ],
            ),
            Row(
              children: [
                Text(
                  getVerboseDateTimeRepresentation(
                      issue.lastMessage?.timestamp.toLocal() ??
                          issue.timestamp.toLocal()),
                  style: theme.textTheme.ppMori400Black14
                      .copyWith(color: AppColor.auQuickSilver),
                ),
                const SizedBox(width: 14),
                SvgPicture.asset('assets/images/iconForward.svg'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 17),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(
            children: [
              if (issue.status == 'closed') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(64),
                    border: Border.all(
                      color: AppColor.auQuickSilver,
                    ),
                  ),
                  child: Text(
                    'resolved'.tr(),
                    style: theme.textTheme.ppMori400FFQuickSilver12,
                  ),
                ),
                const SizedBox(
                  width: 14,
                )
              ],
              Expanded(
                child: Text(
                  getPreviewMessage(issue),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.ppMori400Black14,
                ),
              ),
            ],
          ),
        ),
        if (hasDivider)
          addDivider()
        else
          const SizedBox(
            height: 32,
          ),
      ],
    );
  }

  Widget _announcementRow(Announcement announcement, bool hasDivider) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    announcement.getListTitle(),
                    style: theme.textTheme.ppMori400Black16,
                  ),
                  if (announcement is AnnouncementLocal &&
                      !announcement.read) ...[
                    _unreadChatThreadWidget(),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  getVerboseDateTimeRepresentation(announcement.startedAt),
                  style: theme.textTheme.ppMori400Black14
                      .copyWith(color: AppColor.auQuickSilver),
                ),
                const SizedBox(width: 14),
                SvgPicture.asset('assets/images/iconForward.svg'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 17),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Text(
            announcement.content.isNotEmpty
                ? announcement.content
                : 'announcement'.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.ppMori400Black14,
          ),
        ),
        if (hasDivider)
          addDivider()
        else
          const SizedBox(
            height: 32,
          ),
      ],
    );
  }

  String getPreviewMessage(Issue issue) {
    if (issue.status == 'closed') {
      return _getDisplayMessage(issue, issue.firstMessage);
    } else {
      return _getDisplayMessage(issue, issue.lastMessage);
    }
  }

  String _getDisplayMessage(Issue issue, Message? message) {
    if (issue.draft != null) {
      final draft = issue.draft!;
      final draftData = draft.draftData;

      List<ReceiveAttachment> attachments = [];
      if (draftData.attachments != null) {
        final contentType =
            draft.type == CSMessageType.postPhotos.rawValue ? 'image' : 'logs';
        attachments = draftData.attachments!
            .map((e) => ReceiveAttachment(
                  title: e.fileName,
                  name: '',
                  contentType: contentType,
                ))
            .toList();
      }

      message = Message(
        id: Random.secure().nextInt(100000),
        read: true,
        from: 'did:key:user',
        message: draftData.text ?? '',
        attachments: attachments,
        timestamp: draft.createdAt,
      );
    }

    if (message == null) {
      return '';
    }

    if (message.filteredMessage.isNotEmpty) {
      return message.filteredMessage;
    }
    if (message.attachments.isEmpty) {
      return '';
    }
    final attachment = message.attachments.last;
    final attachmentTitle =
        ReceiveAttachment.extractSizeAndRealTitle(attachment.title)[1]
            as String;
    if (attachment.contentType.contains('image')) {
      return 'image_sent'
          .tr(args: [attachmentTitle]); //'Image sent: $attachmentTitle';
    } else {
      return 'file_sent'
          .tr(args: [attachmentTitle]); //'File sent: $attachmentTitle';
    }
  }

  Widget _unreadChatThreadWidget() => Row(
        children: [
          const SizedBox(width: 8),
          Padding(padding: const EdgeInsets.only(top: 4), child: redDotIcon())
        ],
      );
}
