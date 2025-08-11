//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/additional_data/additional_data.dart';
import 'package:autonomy_flutter/model/additional_data/call_to_action.dart';
import 'package:autonomy_flutter/service/announcement/announcement_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/notifications/notification_type.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:overlay_support/overlay_support.dart';
// ignore: implementation_imports
import 'package:overlay_support/src/overlay_state_finder.dart';
import 'package:url_launcher/url_launcher_string.dart';

class _SimpleNotificationToast extends StatelessWidget {
  final String notification;
  final Function()? openedHandler;
  final Widget? leading;
  final Widget? rightBottomWidget;
  final List<InlineSpan>? addOnTextSpan;

  const _SimpleNotificationToast({
    required Key key,
    required this.notification,
    this.openedHandler,
    this.leading,
    this.rightBottomWidget,
    this.addOnTextSpan,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: GestureDetector(
        onTap: () {
          hideOverlay(key!);
          openedHandler?.call();
        },
        child: Container(
          padding: rightBottomWidget != null
              ? const EdgeInsets.fromLTRB(15, 40, 15, 10)
              : const EdgeInsets.symmetric(vertical: 30, horizontal: 60),
          decoration: BoxDecoration(
            color: theme.auGreyBackground,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  leading ?? const SizedBox(),
                  SizedBox(
                    width: leading != null ? 8 : 0,
                  ),
                  Flexible(
                    child: RichText(
                      text: TextSpan(
                        text: notification,
                        style: theme.textTheme.ppMori400White14,
                        children: addOnTextSpan,
                      ),
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              if (rightBottomWidget != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [rightBottomWidget!],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBannerNotification extends StatefulWidget {
  final String notification;
  final AdditionalData additionalData;
  final Function? openedHandler;
  final DateTime? receivedTime;

  const _TopBannerNotification({
    required Key key,
    required this.notification,
    required this.additionalData,
    this.openedHandler,
    this.receivedTime,
  }) : super(key: key);

  @override
  State<_TopBannerNotification> createState() => _TopBannerNotificationState();
}

class _TopBannerNotificationState extends State<_TopBannerNotification> {
  Timer? _timer;
  String _timeString = '';

  @override
  void initState() {
    super.initState();
    if (widget.receivedTime != null) {
      _updateTimeString();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final now = DateTime.now();
    final difference = now.difference(widget.receivedTime!);

    _timer?.cancel();

    if (difference.inMinutes < 60) {
      // Update every minute for the first hour
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
        final updatedDifference =
            DateTime.now().difference(widget.receivedTime!);
        if (updatedDifference.inMinutes >= 60) {
          // Switch to hourly updates
          _startTimer();
        } else {
          _updateTimeString();
        }
      });
    } else {
      // For notifications over 1 hour old:
      // First, schedule update at the next hour mark
      final minutesUntilNextHour = 60 - (difference.inMinutes % 60);
      _timer = Timer(Duration(minutes: minutesUntilNextHour), () {
        _updateTimeString();
        // Then switch to regular hourly updates
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(hours: 1), (_) {
          _updateTimeString();
        });
      });
    }
  }

  void _updateTimeString() {
    if (mounted) {
      setState(() {
        _timeString = _getReceivedTimeString();
      });
    }
  }

  String _getReceivedTimeString() {
    final now = DateTime.now();
    final difference = now.difference(widget.receivedTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${minutes}m ago';
    } else {
      final hours = difference.inHours;
      return '${hours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.auGreyBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: widget.notification,
              style: theme.textTheme.ppMori400White14,
              children: [
                if (widget.additionalData.cta != null) ...[
                  TextSpan(
                    text:
                        ' ${widget.additionalData.cta!.text ?? 'Tap to view'}',
                    style: theme.textTheme.ppMori400FFYellow14
                        .copyWith(color: AppColor.feralFileLightBlue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        hideOverlay(widget.key!);
                        await widget.additionalData.handleTap(context);
                        widget.openedHandler?.call();
                      },
                  ),
                ]
              ],
            ),
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (widget.receivedTime != null)
                Text(
                  _timeString,
                  style: theme.textTheme.ppMori400Grey12.copyWith(
                    color: AppColor.secondarySpanishGrey,
                  ),
                ),
              const SizedBox(),
              GestureDetector(
                child: Text(
                  'dismiss'.tr(),
                  style: theme.textTheme.ppMori400Grey12.copyWith(
                    color: AppColor.secondarySpanishGrey,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColor.secondarySpanishGrey,
                  ),
                ),
                onTap: () => {hideOverlay(widget.key!)},
              )
            ],
          )
        ],
      ),
    );
  }
}

class _PopUpOverlayNotification extends StatelessWidget {
  final String notification;
  final AdditionalData additionalData;
  final Function? openedHandler;

  const _PopUpOverlayNotification({
    required Key key,
    required this.notification,
    required this.additionalData,
    this.openedHandler,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (additionalData.title != null)
              Text(
                additionalData.title!,
                style: theme.textTheme.ppMori700White18,
              ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Markdown(
                  key: const Key('githubMarkdown'),
                  data: notification,
                  softLineBreak: true,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  styleSheet: markDownAnnouncementStyle(context),
                  onTapLink: (text, href, title) async {
                    if (href == null) {
                      return;
                    }
                    if (href.isAutonomyDocumentLink) {
                      await injector<NavigationService>()
                          .openAutonomyDocument(href, title);
                    } else {
                      await launchUrlString(href);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                if (additionalData.cta != null)
                  PrimaryButton(
                    text: additionalData.cta!.text ?? '',
                    onTap: () async {
                      Navigator.of(context).pop();
                      if (additionalData.cta!.navigationRoute !=
                          CTATarget.general) {
                        await injector<NavigationService>().navigatePath(
                          additionalData.cta!.navigationRoute.toString(),
                        );
                      }
                    },
                  ),
                if (additionalData.listCustomCta != null &&
                    additionalData.listCustomCta!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ...additionalData.listCustomCta!.map(
                    (cta) => GestureDetector(
                      child: Text(
                        cta.text ?? '',
                        style: theme.textTheme.ppMori400White14.copyWith(
                          color: AppColor.auGrey,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColor.secondarySpanishGrey,
                        ),
                      ),
                      onTap: () async {
                        Navigator.of(context).pop();
                        if (cta.navigationRoute != CTATarget.general) {
                          await injector<NavigationService>().navigatePath(
                            cta.navigationRoute.toString(),
                          );
                        }
                      },
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

OverlaySupportEntry showTopBannerNotification(
  BuildContext context, {
  required String id,
  required String body,
  required AdditionalData additionalData,
  Function? handler,
  DateTime? receivedTime,
}) =>
    showSimpleNotification(
      _TopBannerNotification(
        key: Key(id),
        notification: body,
        additionalData: additionalData,
        openedHandler: handler,
        receivedTime: receivedTime,
      ),
      key: Key(id),
      background: Colors.transparent,
      elevation: 0,
      autoDismiss: false,
      slideDismissDirection: DismissDirection.up,
    );

Future<void> showPopupOverlayNotification(
  BuildContext context, {
  required String id,
  required String body,
  required AdditionalData additionalData,
  Function? handler,
}) async {
  if (context.mounted) {
    await UIHelper.showCenterSheet(
      context,
      content: _PopUpOverlayNotification(
        key: Key(id),
        notification: body,
        additionalData: additionalData,
        openedHandler: handler,
      ),
      withExitButton: false,
      verticalPadding: 0,
      // radius: 10,
      backgroundColor: AppColor.auGreyBackground,
    );
  }
}

Future<void> showInAppNotifications(
  BuildContext context,
  String id,
  AdditionalData additionalData, {
  Function? handler,
  Function? callBackOnDismiss,
  String? body,
  DateTime? receivedTime,
}) async {
  final configurationService = injector<ConfigurationService>();
  if (configurationService.showingNotification.value) {
    return;
  }

  configurationService.showingNotification.value = true;

  // Vibrate.feedback(FeedbackType.warning);
  if (additionalData.notificationType == NotificationType.announcement) {
    await showPopupOverlayNotification(
      context,
      id: id,
      body: body ?? '',
      additionalData: additionalData,
      handler: handler,
    );
  } else {
    final notification = showTopBannerNotification(
      context,
      id: id,
      body: body ?? '',
      receivedTime: receivedTime,
      additionalData: additionalData,
      handler: handler,
    );
    await notification.dismissed;
  }

  await injector<AnnouncementService>().markAsRead(id);
  configurationService.showingNotification.value = false;

  /// always show next announcement in queue, event user tap to see it
  Future.delayed(const Duration(milliseconds: 100), () {
    callBackOnDismiss?.call();
  });
}

void showSimpleNotificationToast({
  required Key key,
  required String content,
  Function? handler,
  Function? callBackOnDismiss,
  Duration? duration,
  Widget? leading,
  Widget? rightBottomWidget,
  bool autoDismiss = true,
  List<InlineSpan>? addOnTextSpan,
  // FeedbackType? vibrateFeedbackType,
}) {
  showSimpleNotification(
    _SimpleNotificationToast(
      key: key,
      notification: content,
      leading: leading,
      rightBottomWidget: rightBottomWidget,
      addOnTextSpan: addOnTextSpan,
      openedHandler: () {
        handler?.call();
      },
    ),
    background: Colors.transparent,
    elevation: 0,
    autoDismiss: autoDismiss,
    duration: duration ?? const Duration(seconds: 3),
    key: key,
    slideDismissDirection: DismissDirection.up,
  );

  // Vibrate.feedback(vibrateFeedbackType ?? FeedbackType.light);
}

void hideOverlay(Key key) {
  final OverlaySupportState? overlaySupport = findOverlayState();
  if (overlaySupport == null) {
    log.warning('Cannot find overlay key: $key');
    return;
  }

  final overlayEntry = overlaySupport.getEntry(key: key);

  overlayEntry?.dismiss();
}
