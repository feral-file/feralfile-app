import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/connect_ff1_page.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Helper class to handle BLE-based FF1 setup flow.
/// Replaces QR-based setup with BLE discovery.
class BLESetupHelper {
  /// Handle BLE-discovered device setup.
  static Future<void> handleBLEDeviceSetup(
    BluetoothDevice device,
  ) async {
    log.info(
      '[BLESetupHelper] Handling BLE device setup for: ${device.advName}',
    );

    // Navigate to connect page
    // Device info will be fetched via get_info command after connection
    await injector<NavigationService>().navigateTo(
      AppRouter.connectFF1,
      arguments: ConnectFF1PagePayload(
        device: device,
        onConnectedSuccess: (String branchName) async {
          await _proceedWithWifiSetup(device, branchName);
        },
      ),
    );
  }

  static Future<void> _proceedWithWifiSetup(
    BluetoothDevice device,
    String branchName,
  ) async {
    await injector<NavigationService>().navigateTo(
      AppRouter.scanWifiNetworkPage,
      arguments: ScanWifiNetworkPagePayload(
        device,
        (accessPoint) async {
          await _onWifiSelected(accessPoint, device, branchName);
        },
      ),
    );
    await device.disconnect();
  }

  static Future<void> _onWifiSelected(
    WifiPoint accessPoint,
    BluetoothDevice device,
    String branchName,
  ) async {
    log.info('[BLESetupHelper] onWifiSelected: $accessPoint');
    final payload = SendWifiCredentialsPagePayload(
      wifiAccessPoint: accessPoint,
      device: device,
      onSubmitted: (String? topicId, Object? error) async {
        final res = topicId != null ? Pair(topicId, true) : null;
        if (res != null) {
          final ffDevice = device.toFFBluetoothDevice(
            topicId: res.first,
            deviceId: device.advName,
            branchName: branchName,
          );
          await BluetoothDeviceManager().addDevice(ffDevice);
          await injector<CanvasClientServiceV2>()
              .showPairingQRCode(ffDevice, false);

          injector<NavigationService>().popUntil(AppRouter.startSetupFF1Page);
          unawaited(injector<NavigationService>().popAndPushNamed(
            AppRouter.bluetoothConnectedDeviceConfig,
            arguments: BluetoothConnectedDeviceConfigPayload(
              isFromOnboarding: true,
            ),
          ));
        } else if (error != null) {
          injector<NavigationService>().popUntil(AppRouter.startSetupFF1Page);
          injector<NavigationService>().goBack();
        }
      },
    );
    injector<NavigationService>()
        .navigateTo(AppRouter.sendWifiCredentialPage, arguments: payload);
  }
}
