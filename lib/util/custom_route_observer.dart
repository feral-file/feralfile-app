import 'dart:async';

import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
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
];

class CustomRouteObserver<R extends Route<dynamic>> extends RouteObserver<R> {
  static Route<dynamic>? currentRoute;

  static final bottomSheetVisibility = ValueNotifier<bool>(false);
  static final bottomSheetHeight = ValueNotifier<double>(0);

  static bool get onIgnoreBackLayerPopUp => bottomSheetVisibility.value;

  Timer? _timer;

  void onCurrentRouteChanged() {
    if (currentRoute != null) {
      final routeName = currentRoute!.settings.name;
      if (routeName == null ||
          routeName == UIHelper.ignoreBackLayerPopUpRouteName ||
          routeName == UIHelper.artDisplaySettingModal) {
        return;
      }
      if (listRouteShouldNotShowNowDisplaying.contains(routeName)) {
        _timer?.cancel();
        _timer = Timer.periodic(Duration(milliseconds: 50), (_) {
          _timer?.cancel();
        });
      } else {
        _timer?.cancel();
        _timer = Timer.periodic(Duration(milliseconds: 50), (_) {
          _timer?.cancel();
        });
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

    currentRoute = route;
    onCurrentRouteChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    currentRoute = previousRoute;
    onCurrentRouteChanged();

    /// this must be put after super.didPop
    if (route is ModalBottomSheetRoute) {
      bottomSheetVisibility.value = false;
      bottomSheetHeight.value = 0;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    currentRoute = newRoute;
    onCurrentRouteChanged();
  }
}
