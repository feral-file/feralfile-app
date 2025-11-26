//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/customer_support/support_thread_page.dart';
import 'package:autonomy_flutter/screen/report/sentry_report.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/shared.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/custom_exception.dart';
import 'package:autonomy_flutter/util/exception.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// import 'package:tezart/tezart.dart';

enum ErrorItemState {
  getReport,
  thanks,
  close,
  tryAgain,
  settings,
  camera,
  seeAccount,
  general,
}

const onlySentryExceptionIdentifier = [
  'Future already completed',
  'Out of Memory'
];

class ErrorEvent {
  Object? err;
  String title;
  String message;
  ErrorItemState state;

  ErrorEvent(this.err, this.title, this.message, this.state);

  bool shouldShowPopup() {
    switch (state) {
      case ErrorItemState.getReport:
      case ErrorItemState.thanks:
      case ErrorItemState.close:
      case ErrorItemState.tryAgain:
      case ErrorItemState.settings:
      case ErrorItemState.camera:
      case ErrorItemState.seeAccount:
        return true;
      default:
        return false;
    }
  }
}

PlatformException? lastException;

extension DioErrorEvent on DioException {
  ErrorEvent? get errorEvent {
    log.info('Dio Error: $this');
    switch (type) {
      case DioExceptionType.badResponse:
        if ((response?.statusCode ?? 0) / 100 == 5) {
          return ErrorEvent(
              null,
              'Server error',
              'We apologise and are fixing the problem.'
                  '\nPlease try again at later stage.',
              ErrorItemState.close);
        } else {
          return null;
        }
      default:
        return null;
    }
  }
}

ErrorEvent translateError(Object exception) {
  if (exception is DioException) {
    final dioErrorEvent = exception.errorEvent;
    if (dioErrorEvent != null) {
      return dioErrorEvent;
    }
    // } else if (exception is CameraException) {
    //   return ErrorEvent(null, 'enable_camera'.tr(), 'qr_scan_require'.tr(),
    //       ErrorItemState.camera);
  } else if (exception is PlatformException) {
    switch (exception.code) {
      case 'invalidDeeplink':
        return ErrorEvent(
            exception, '😵', 'link_not_valid'.tr(), ErrorItemState.close);
      default:
        break;
    }
  } else if (exception is LinkingFailedException) {
    return ErrorEvent(exception, '🤔', 'problem_connect_wallet'.tr(),
        ErrorItemState.getReport);
  }

  if (exception is JwtException) {
    return ErrorEvent(exception, 'can_not_authenticate'.tr(), exception.message,
        ErrorItemState.getReport);
  }

  if (exception is ErrorBindingException) {
    return ErrorEvent(exception, 'binding_data_issue'.tr(), exception.message,
        ErrorItemState.general);
  }

  return ErrorEvent(
      exception,
      'Oops! Something went wrong',
      'It looks like there’s a small hiccup on our end. We’re on it and should '
          'have things fixed soon. Apologies for any inconvenience!',
      ErrorItemState.general);
}

bool onlySentryException(Object exception) {
  if (onlySentryExceptionIdentifier
      .any((element) => exception.toString().contains(element))) {
    return true;
  }

  if (exception is PlatformException) {
    switch (exception.code) {
      case 'VideoError':
        return true;
      default:
        return false;
    }
  }

  return false;
}

DateTime? isShowErrorDialogWorking;

Future showErrorDialog(BuildContext context, String title, String description,
    String defaultButton,
    [Function()? defaultButtonOnPress,
    String? cancelButton,
    Function()? cancelButtonOnPress]) async {
  if (isShowErrorDialogWorking != null &&
      isShowErrorDialogWorking!
              .add(const Duration(seconds: 2))
              .compareTo(DateTime.now()) >
          0) {
    log.info('showErrorDialog is working');
    return;
  }

  isShowErrorDialogWorking = DateTime.now();
  final theme = Theme.of(context);

  // Vibrate.feedback(FeedbackType.warning);
  await showModalBottomSheet(
      context: context,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
          maxWidth: ResponsiveLayout.isMobile
              ? double.infinity
              : Constants.maxWidthModalTablet),
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => Container(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: theme.auGreyBackground,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: theme.primaryTextTheme.ppMori700White24),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    Text(
                      description,
                      style: theme.primaryTextTheme.ppMori400White14,
                    ),
                    const SizedBox(height: 40),
                    PrimaryButton(
                      text: defaultButton,
                      onTap: () {
                        Navigator.of(context).pop();
                        if (defaultButtonOnPress != null) {
                          defaultButtonOnPress();
                        }
                      },
                    ),
                    if (cancelButton != null) ...[
                      const SizedBox(height: 10),
                      OutlineButton(
                        text: cancelButton,
                        onTap: () {
                          Navigator.of(context).pop();

                          if (cancelButtonOnPress != null) {
                            cancelButtonOnPress();
                          }
                        },
                      ),
                    ]
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ));

  await Future.delayed(const Duration(seconds: 1), () {
    isShowErrorDialogWorking = null;
  });
}

void showEventErrorDialog(
  BuildContext context,
  ErrorEvent event, {
  Function()? defaultAction,
  Function()? cancelAction,
}) {
  String defaultButton = '';
  String? cancelButton;
  switch (event.state) {
    case ErrorItemState.close:
      defaultButton = 'close'.tr();

    case ErrorItemState.getReport:
      defaultButton = 'get_support'.tr();
      cancelButton = 'continue'.tr();

    case ErrorItemState.tryAgain:
      defaultButton = 'try_again'.tr();
      cancelButton = cancelAction != null ? 'close'.tr() : null;

    case ErrorItemState.camera:
      defaultButton = 'open_settings'.tr();
      defaultAction = () async => await openAppSettings();

    case ErrorItemState.seeAccount:
      defaultButton = 'see_account'.tr();
      cancelButton = 'close'.tr();

    default:
      break;
  }
  unawaited(showErrorDialog(context, event.title, event.message, defaultButton,
      defaultAction, cancelButton, cancelAction));
}

Future<bool> showErrorDialogFromException(Object exception,
    {StackTrace? stackTrace, String? library}) async {
  unawaited(Sentry.captureException(exception,
      stackTrace: stackTrace,
      withScope: (Scope? scope) => scope?.setTag('library', library ?? '')));
  final navigationService = injector<NavigationService>();
  final context = navigationService.navigatorKey.currentContext;

  if (exception is PlatformException) {
    if (lastException != null && lastException?.message == exception.message) {
      return true;
    }
    lastException = exception;
  } else if (context != null) {
    if (exception is AbortedException) {
      unawaited(UIHelper.showInfoDialog(
          context, 'aborted'.tr(), 'action_aborted'.tr(),
          isDismissible: true, autoDismissAfter: 3));
      return true;
    } else if (exception is InvalidDeeplink) {
      unawaited(UIHelper.showInfoDialog(context, '😵', 'link_not_valid'.tr(),
          isDismissible: true, autoDismissAfter: 3));
      return true;
    }
  }

  // avoid to bother user when user has just foregrounded the app.
  if (memoryValues.inForegroundAt != null &&
      DateTime.now()
              .subtract(const Duration(seconds: 5))
              .compareTo(memoryValues.inForegroundAt!) <
          0) {
    return true;
  }

  log
    ..warning('Unhandled error: $exception', exception, stackTrace)
    ..warning('StackTrace: $stackTrace');

  if (library != null || onlySentryException(exception)) {
    // Send error directly to Sentry if it comes from specific libraries
    return true;
  }

  final event = translateError(exception);
  if (context != null) {
    if (event.state == ErrorItemState.getReport) {
      final sentryID = await reportSentry(
          {'exception': exception, 'stackTrace': stackTrace});
      var sentryMetadata = '';
      if (sentryID == '00000000000000000000000000000000') {
        sentryMetadata = exception.toString();
      }

      navigationService.showErrorDialog(
        event,
        defaultAction: () => Navigator.of(context).pushNamed(
          AppRouter.supportThreadPage,
          arguments: ExceptionErrorPayload(
              sentryID: sentryID, metadata: sentryMetadata),
        ),
      );
      return true;
    } else {
      if (!_isErrorIgnored(event)) {
        navigationService.showErrorDialog(event);
      }
      return true;
    }
  } else {
    return false;
  }
}

bool _isErrorIgnored(ErrorEvent event) {
  final exception = event.err;
  if (exception is RangeError ||
      exception is FlutterError ||
      exception is PlatformException) {
    return true;
  }
  return !event.shouldShowPopup();
}

void hideInfoDialog(BuildContext context) {
  Navigator.of(context).pop();
}

enum TezosError {
  notEnoughMoney,
  contractMalformed,
  other,
}
