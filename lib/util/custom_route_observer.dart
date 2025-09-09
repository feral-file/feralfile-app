import 'dart:async';

import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

final listRouteShouldNotShowNowDisplaying = [
  AppRouter.scanQRPage,
  AppRouter.settingsPage,
  AppRouter.supportCustomerPage,
  AppRouter.supportListPage,
  AppRouter.supportThreadPage,
  AppRouter.walletPage,
  AppRouter.linkedWalletDetailsPage,
  AppRouter.preferencesPage,
  AppRouter.hiddenArtworksPage,
  AppRouter.dataManagementPage,
  AppRouter.bugBountyPage,
  AppRouter.nowDisplayingPage,
  AppRouter.onboardingPage,
  AppRouter.newOnboardingPage,
  AppRouter.bluetoothConnectedDeviceConfig,
  AppRouter.bluetoothDevicePortalPage,
  AppRouter.handleBluetoothDeviceScanDeeplinkScreen,
  AppRouter.sendWifiCredentialPage,
  AppRouter.scanWifiNetworkPage,
  AppRouter.viewExistingAddressPage,
  AppRouter.nameLinkedAccountPage,
  UIHelper.artistArtworkDisplaySettingModal,
  AppRouter.oldHomePage,
  AppRouter.voiceCommandPage,
];

class CustomRouteObserver<R extends Route<dynamic>> extends RouteObserver<R> {
  static ValueNotifier<Route<dynamic>?> currentRoute =
      ValueNotifier<Route<dynamic>?>(null);

  static final bottomSheetVisibility = ValueNotifier<bool>(false);
  static final bottomSheetHeight = ValueNotifier<double>(0);

  // Stack to track all screens
  static final List<Route<dynamic>> _screenStack = [];

  // Getter to access the screen stack
  static List<Route<dynamic>> get screenStack =>
      List.unmodifiable(_screenStack);

  // Getter to get the current screen count
  static int get screenCount => _screenStack.length;

  static bool get onIgnoreBackLayerPopUp => bottomSheetVisibility.value;

  Timer? _timer;

  void onCurrentRouteChanged() {
    if (currentRoute != null) {
      final routeName = currentRoute.value?.settings.name;
      if (routeName == null ||
          routeName == UIHelper.ignoreBackLayerPopUpRouteName ||
          routeName == UIHelper.artDisplaySettingModal) {
        return;
      }
      if (listRouteShouldNotShowNowDisplaying.contains(routeName)) {
        _timer?.cancel();
        _timer = Timer.periodic(Duration(milliseconds: 50), (_) {
          _timer?.cancel();
          shouldShowNowDisplaying.value = false;
        });
      } else {
        log.info('shouldShowNowDisplaying.value = true');
        _timer?.cancel();
        _timer = Timer.periodic(Duration(milliseconds: 50), (_) {
          _timer?.cancel();
          shouldShowNowDisplaying.value = true;
          nowDisplayingVisibility.value = true;
        });
        // shouldShowNowDisplaying.value = true;
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalBottomSheetRoute) {
      final key = (route.settings.arguments as Map<String, dynamic>?)?['key']
          as GlobalKey?;
      if (key != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final box = key.currentContext?.findRenderObject() as RenderBox?;
          if (box != null) {
            bottomSheetHeight.value = box.size.height;
          }
        });
      }
      bottomSheetVisibility.value = true;
    }
    super.didPush(route, previousRoute);

    // Add route to the screen stack
    _screenStack.add(route);
    log.info(
        'Route pushed: ${route.settings.name}, Stack size: ${_screenStack.length}');

    currentRoute.value = route;
    onCurrentRouteChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    // Remove route from the screen stack
    if (_screenStack.isNotEmpty && _screenStack.last == route) {
      _screenStack.removeLast();
      log.info(
          'Route popped: ${route.settings.name}, Stack size: ${_screenStack.length}');
    }

    currentRoute.value = previousRoute;
    onCurrentRouteChanged();

    /// this must be put after super.didPop
    if (route is ModalBottomSheetRoute) {
      bottomSheetVisibility.value = false;
      bottomSheetHeight.value = 0;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    // Remove route from the screen stack
    _screenStack.remove(route);
    log.info(
        'Route removed: ${route.settings.name}, Stack size: ${_screenStack.length}');

    currentRoute.value = previousRoute;
    onCurrentRouteChanged();

    if (route is ModalBottomSheetRoute) {
      bottomSheetVisibility.value = false;
      bottomSheetHeight.value = 0;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    // Replace old route with new route in the stack
    if (oldRoute != null && newRoute != null) {
      final index = _screenStack.indexOf(oldRoute);
      if (index != -1) {
        _screenStack[index] = newRoute;
        log.info(
            'Route replaced: ${oldRoute.settings.name} -> ${newRoute.settings.name}, Stack size: ${_screenStack.length}');
      }
    }

    currentRoute.value = newRoute;
    onCurrentRouteChanged();

    if (oldRoute is ModalBottomSheetRoute) {
      bottomSheetVisibility.value = false;
      bottomSheetHeight.value = 0;
    }
  }

  // Helper method to get the previous screen
  static Route<dynamic>? getPreviousScreen() {
    if (_screenStack.length > 1) {
      return _screenStack[_screenStack.length - 2];
    }
    return null;
  }

  // Helper method to check if a specific route is in the stack
  static bool isRouteInStack(String routeName) {
    return _screenStack.any((route) => route.settings.name == routeName);
  }

  // Helper method to get all route names in the stack
  static List<String?> getRouteNames() {
    return _screenStack.map((route) => route.settings.name).toList();
  }
}

extension RouterExtension on Route<dynamic> {
  //isRecordScreenShowing
  bool get isRecordScreenShowing {
    return this is CupertinoPageRoute &&
        (this as CupertinoPageRoute).settings.name ==
            AppRouter.voiceCommandPage;
  }

  // isArtDisplaySettingModalShowing
  bool get isArtDisplaySettingModalShowing {
    return this.settings.name == UIHelper.artDisplaySettingModal;
  }
}
