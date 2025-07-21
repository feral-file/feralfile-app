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
import 'package:autonomy_flutter/model/ff_account.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/check_bluetooth_state.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/auth_service.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/dio_exception_ext.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Completer<void> startHandleDeeplinkCompleter = Completer<void>();

abstract class DeeplinkService {
  Future<void> setup();

  void handleDeeplink(String? link, {Duration delay, Function? onFinished});

  // void handleBranchDeeplinkData(Map<dynamic, dynamic> data);

  Future<void> handleReferralCode(String referralCode);
}

class DeeplinkServiceImpl extends DeeplinkService {
  DeeplinkServiceImpl(
    this._configurationService,
    this._navigationService,
  );

  final ConfigurationService _configurationService;
  final NavigationService _navigationService;

  final Map<String, bool> _deepLinkHandlingMap = {};

  @override
  Future<void> setup() async {
    log.info('[DeeplinkService] setup');

    try {
      final appLink = AppLinks();
      final initialLink = await appLink.getInitialLinkString();
      log.info('[DeeplinkService] initialLink: $initialLink');
      if (initialLink != null) {
        handleDeeplink(initialLink);
      }

      appLink.uriLinkStream.listen((link) {
        log.info('[DeeplinkService] uriLinkStream: $link');
        handleDeeplink(link.toString());
      });
    } on PlatformException {
      //Ignore
    }
  }

  @override
  void handleDeeplink(
    String? link, {
    Duration delay = Duration.zero,
    Function? onFinished,
  }) {
    // return for case when FeralFile pass empty deeplink to return Autonomy
    if (link == 'autonomy://') {
      return;
    }

    if (link == null) {
      return;
    }

    log.info('[DeeplinkService] receive deeplink $link');

    Timer.periodic(delay, (timer) async {
      timer.cancel();
      if (_deepLinkHandlingMap[link] != null) {
        log.info('[DeeplinkService] deeplink $link is handling');
        return;
      }
      await startHandleDeeplinkCompleter.future;

      _deepLinkHandlingMap[link] = true;
      final handlerType = DeepLinkHandlerType.fromString(link);

      Future<void> onFinishDeeplink() async {
        try {
          await onFinished?.call();
        } catch (e) {
          log.info('[DeeplinkService] onFinishDeeplink error: $e');
        }
        _deepLinkHandlingMap.remove(link);
      }

      log.info('[DeeplinkService] handlerType $handlerType');
      switch (handlerType) {
        case DeepLinkHandlerType.navigation:
          await _handleNavigationDeeplink(link);
        case DeepLinkHandlerType.homeWidget:
          await _handleHomeWidgetDeeplink(link);
        case DeepLinkHandlerType.bluetoothConnect:
          await _handleBluetoothConnectDeeplink(
            link,
            onFinish: onFinishDeeplink,
          );
        case DeepLinkHandlerType.linkArtist:
          await _handleLinkArtistDeeplink(link);
        case DeepLinkHandlerType.unknown:
          unawaited(_navigationService.showUnknownLink());
      }
      if (handlerType != DeepLinkHandlerType.bluetoothConnect) {
        await onFinishDeeplink.call();
      }
      // this function is called in onFinishDeeplink, so we don't need to call it here
      // _deepLinkHandlingMap.remove(link);
    });
  }

  Future<bool> _handleNavigationDeeplink(String link) async {
    log.info('[DeeplinkService] _handleNavigationDeeplink');

    final navigationPrefixes = [
      'feralfile://navigation/',
    ];

    final callingNavigationPrefix = navigationPrefixes
        .firstWhereOrNull((prefix) => link.startsWith(prefix));
    if (callingNavigationPrefix != null) {
      final navigationPath = link.replaceFirst(callingNavigationPrefix, '');
      await _navigationService.navigatePath(navigationPath);
      return true;
    }
    return false;
  }

  Future<bool> _handleHomeWidgetDeeplink(String link) async {
    log.info('[DeeplinkService] _handleHomeWidgetDeeplink');
    final homeWidgetPrefix = Constants.homeWidgetDeepLinks
        .firstWhereOrNull((prefix) => link.startsWith(prefix));
    if (homeWidgetPrefix != null) {
      final urlDecode = Uri.decodeFull(link.replaceFirst(homeWidgetPrefix, ''));
      final uri = Uri.tryParse(urlDecode);
      if (uri == null) {
        return false;
      }

      final widget = uri.queryParameters['widget'];
      switch (widget) {
        case 'daily':
          try {
            await _navigationService.navigatePath(
              AppRouter.dailyWorkPage,
            );
          } catch (e) {
            log.info('[DeeplinkService] navigatePath to dailyPage error: $e');
          }

        default:
          break;
      }
      return true;
    }
    return false;
  }

  Future<void> _handleBluetoothConnectDeeplink(
    String link, {
    Function? onFinish,
  }) async {
    final prefix = Constants.bluetoothConnectDeepLinks
        .firstWhereOrNull((prefix) => link.startsWith(prefix));
    if (prefix == null) {
      log.info(
        '[DeeplinkService] _handleBluetoothConnectDeeplink prefix not found',
      );
      return;
    }
    unawaited(
      injector<ConfigurationService>().setDidShowLiveWithArt(true).then((_) {
        log.info('setDidShowLiveWithArt to true');
      }),
    );

    await injector<NavigationService>().navigateTo(
      AppRouter.handleBluetoothDeviceScanDeeplinkScreen,
      arguments: HandleBluetoothDeviceScanDeeplinkScreenPayload(
        deeplink: link,
        onFinish: onFinish,
      ),
    );
  }

  // handler for link artist deeplink
  Future<void> _handleLinkArtistDeeplink(String link) async {
    log.info('[DeeplinkService] _handleLinkArtistDeeplink');
    final linkArtistPrefix = Constants.linkArtistDeepLinks
        .firstWhereOrNull((prefix) => link.startsWith(prefix));
    if (linkArtistPrefix == null) {
      log.info('[DeeplinkService] _handleLinkArtistDeeplink prefix not found');
      return;
    }
    final token = link.replaceFirst(linkArtistPrefix, '').split('/')[1];
    try {
      await injector<AuthService>().linkArtist(token);
      unawaited(_navigationService.showLinkArtistSuccess());
    } on DioException catch (e) {
      if (e.error is FeralfileError) {
        final error = e.error as FeralfileError;
        if (error.isLinkArtistTokenNotFound) {
          unawaited(_navigationService.showLinkArtistTokenNotFound());
        } else if (error.isLinkArtistAddressAlreadyLinked) {
          unawaited(_navigationService.showLinkArtistAddressAlreadyLinked());
        } else if (error.isLinkArtistUserAlreadyLinked) {
          unawaited(_navigationService.showLinkArtistAddressNotFound());
        } else {
          unawaited(_navigationService.showLinkArtistFailed(e));
        }
      }
    } catch (e) {
      unawaited(_navigationService.showLinkArtistFailed(e));
    }
  }

  // Future<bool> _handleBranchDeeplink(String link, {Function? onFinish}) async {
  //   log.info('[DeeplinkService] _handleBranchDeeplink');
  //   final callingBranchDeepLinkPrefix = Constants.branchDeepLinks
  //       .firstWhereOrNull((prefix) => link.startsWith(prefix));
  //   if (callingBranchDeepLinkPrefix != null) {
  //     try {
  //       final response =
  //           await _branchApi.getParams(Environment.branchKey, link);
  //       await handleBranchDeeplinkData(
  //           response['data'] as Map<dynamic, dynamic>,
  //           onFinish: onFinish);
  //     } catch (e, s) {
  //       unawaited(Sentry.captureException('Branch deeplink error: $e',
  //           stackTrace: s));
  //       log.info('[DeeplinkService] _handleBranchDeeplink error $e');
  //       await _navigationService.showCannotResolveBranchLink();
  //     }
  //     return true;
  //   }
  //   return false;
  // }

  @override
  Future<void> handleReferralCode(String referralCode) async {
    log.info('[DeeplinkService] handleReferralCode $referralCode');
    // save referral code to local storage, for case when user register failed
    await _configurationService.setReferralCode(referralCode);
    try {
      await injector<AddressService>()
          .registerReferralCode(referralCode: referralCode);
      // clear referral code after register success
      await _configurationService.setReferralCode('');
    } catch (e, s) {
      log.info('[DeeplinkService] _handleReferralCode error $e');
      unawaited(
        Sentry.captureException('Referral code error: $e', stackTrace: s),
      );
      if (e is DioException) {
        if (e.isAlreadySetReferralCode) {
          log.info('[DeeplinkService] referral code already set');
          // if referral code is already set, clear it
          await _configurationService.setReferralCode('');
        }
      }
    }
  }
}

enum DeepLinkHandlerType {
  navigation,
  homeWidget,
  bluetoothConnect,
  linkArtist,
  unknown,
  ;

  static DeepLinkHandlerType fromString(String value) {
    if (Constants.navigationPrefixes
        .any((prefix) => value.startsWith(prefix))) {
      return DeepLinkHandlerType.navigation;
    }

    if (Constants.homeWidgetDeepLinks
        .any((prefix) => value.startsWith(prefix))) {
      return DeepLinkHandlerType.homeWidget;
    }

    if (Constants.bluetoothConnectDeepLinks
        .any((prefix) => value.startsWith(prefix))) {
      return DeepLinkHandlerType.bluetoothConnect;
    }

    if (Constants.linkArtistDeepLinks
        .any((prefix) => value.startsWith(prefix))) {
      return DeepLinkHandlerType.linkArtist;
    }

    return DeepLinkHandlerType.unknown;
  }
}
