//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
// ignore: implementation_imports
import 'package:overlay_support/src/overlay_state_finder.dart';

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
            color: AppColor.auGreyBackground,
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
                        style: AppTypography.body(context).white,
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
