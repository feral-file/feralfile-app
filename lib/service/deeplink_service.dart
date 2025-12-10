//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/screen/device_setting/start_setup_ff1_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

Completer<void> startHandleDeeplinkCompleter = Completer<void>();

abstract class DeeplinkService {
  Future<void> setup();

  void handleDeeplink(
    String? link, {
    Duration delay,
    Function? onFinished,
    bool isFromOnboarding = false,
    bool isFromAppLink = false,
  });

  bool get isHandlingDeepLink;
}

class DeeplinkServiceImpl extends DeeplinkService {
  DeeplinkServiceImpl(
    this._navigationService,
  );

  final NavigationService _navigationService;

  final Map<String, bool> _deepLinkHandlingMap = {};

  @override
  bool get isHandlingDeepLink => _deepLinkHandlingMap.isNotEmpty;

  @override
  Future<void> setup() async {
    log.info('[DeeplinkService] setup');

    try {
      final appLink = AppLinks();
      final initialLink = await appLink.getInitialLinkString();
      log.info('[DeeplinkService] initialLink: $initialLink');
      if (initialLink != null) {
        handleDeeplink(initialLink, isFromAppLink: true);
      }

      appLink.uriLinkStream.listen((link) {
        log.info('[DeeplinkService] uriLinkStream: $link');
        handleDeeplink(link.toString(), isFromAppLink: true);
      });
    } on PlatformException {
      //Ignore
    }
  }

  @override
  void handleDeeplink(
    String? rawLink, {
    Duration delay = Duration.zero,
    Function? onFinished,
    bool isFromOnboarding = false,
    bool isFromAppLink = false,
  }) {
    // return for case when FeralFile pass empty deeplink to return Autonomy
    if (rawLink == 'autonomy://') {
      return;
    }

    if (rawLink == null) {
      return;
    }

    final link = Uri.decodeFull(rawLink);

    log.info('[DeeplinkService] receive deeplink $link');

    Timer.periodic(delay, (timer) async {
      timer.cancel();
      if (_deepLinkHandlingMap[link] != null) {
        log.info('[DeeplinkService] deeplink $link is handling');
        return;
      }
      _deepLinkHandlingMap[link] = true;

      log.info('[DeeplinkService] wait for startHandleDeeplinkCompleter');

      await startHandleDeeplinkCompleter.future;

      log.info('[DeeplinkService] startHandleDeeplinkCompleter completed');

      final handlerType = DeepLinkHandlerType.fromString(link);

      Future<void> onFinishDeeplink() async {
        _deepLinkHandlingMap.remove(link);
        try {
          await onFinished?.call();
        } catch (e) {
          log.info('[DeeplinkService] onFinishDeeplink error: $e');
        }
      }

      log.info('[DeeplinkService] handlerType $handlerType');
      try {
        switch (handlerType) {
          case DeepLinkHandlerType.bluetoothConnect:
            await _handleBluetoothConnectDeeplink(
              link,
              onFinish: onFinishDeeplink,
              isFromOnboarding: isFromOnboarding,
              isFromAppLink: isFromAppLink,
            );
          case DeepLinkHandlerType.unknown:
            unawaited(_navigationService.showUnknownLink());
        }
      } finally {
        await onFinishDeeplink.call();
      }
    });
  }

  Future<void> _handleBluetoothConnectDeeplink(
    String link, {
    Function? onFinish,
    bool isFromOnboarding = false,
    bool isFromAppLink = false,
  }) async {
    final prefix = Constants.bluetoothConnectDeepLinks
        .firstWhereOrNull((prefix) => link.startsWith(prefix));
    if (prefix == null) {
      log.info(
        '[DeeplinkService] _handleBluetoothConnectDeeplink prefix not found',
      );
      return;
    }

    if (isFromOnboarding) {
      await injector<NavigationService>().navigateTo(
        AppRouter.handleBluetoothDeviceScanDeeplinkScreen,
        arguments: HandleBluetoothDeviceScanDeeplinkScreenPayload(
          deeplink: link,
          onFinish: onFinish,
        ),
      );
    } else {
      await injector<NavigationService>().navigateTo(
        AppRouter.startSetupFF1Page,
        arguments: BluetoothDevicePortalPagePayload(
          deeplink: link,
          isFromAppLink: isFromAppLink,
        ),
      );
    }
  }
}

enum DeepLinkHandlerType {
  bluetoothConnect,
  unknown,
  ;

  static DeepLinkHandlerType fromString(String value) {
    if (Constants.bluetoothConnectDeepLinks
        .any((prefix) => value.startsWith(prefix))) {
      return DeepLinkHandlerType.bluetoothConnect;
    }

    return DeepLinkHandlerType.unknown;
  }
}
