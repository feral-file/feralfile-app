import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/error/bluetooth_response_error.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum _ConnectFF1Status {
  connecting,
  stillConnecting,
  error,
  success,
}

class ConnectFF1PagePayload {
  ConnectFF1PagePayload({
    required this.device,
    required this.branchName,
    this.canSkipNetworkSetup = true,
  });

  final BluetoothDevice device;
  final bool canSkipNetworkSetup;
  final String branchName;
}

class ConnectFF1Page extends StatefulWidget {
  const ConnectFF1Page({
    required this.payload,
    super.key,
  });

  final ConnectFF1PagePayload payload;

  @override
  State<ConnectFF1Page> createState() => _ConnectFF1PageState();
}

class _ConnectFF1PageState extends State<ConnectFF1Page> {
  _ConnectFF1Status _status = _ConnectFF1Status.connecting;
  Timer? _stillConnectingTimer;
  DateTime? _startTime;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _setupStillConnectingTimer();
    _startConnectFlow();
  }

  @override
  void dispose() {
    _stillConnectingTimer?.cancel();
    super.dispose();
  }

  void _setupStillConnectingTimer() {
    _stillConnectingTimer = Timer(
      const Duration(seconds: 9),
      () {
        if (!mounted) {
          return;
        }
        if (_status == _ConnectFF1Status.connecting) {
          setState(() {
            _status = _ConnectFF1Status.stillConnecting;
          });
        }
      },
    );
  }

  Future<void> _startConnectFlow() async {
    if (_isConnecting) {
      return;
    }
    _isConnecting = true;
    _status = _ConnectFF1Status.connecting;
    _startTime = DateTime.now();
    log.info('[ConnectFF1Page] Start connecting to FF1');
    try {
      var device = widget.payload.device;
      if (device is FFBluetoothDevice && device.remoteID.isEmpty) {
        log.info(
          '[ConnectFF1Page] Device ${device.name} has empty remoteID, scan and connect',
        );
        device = await injector<FFBluetoothService>().scanAndConnect(device);
      } else {
        await injector<FFBluetoothService>().connectToDevice(device);
      }

      await _handlePostConnect(device);
    } catch (e) {
      log.info('[ConnectFF1Page] Error connecting to device: $e');
      _recordDuration(success: false);
      if (mounted) {
        setState(() {
          _status = _ConnectFF1Status.error;
        });
      }
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _handlePostConnect(BluetoothDevice device) async {
    final canSkipNetworkSetup = widget.payload.canSkipNetworkSetup;
    if (!canSkipNetworkSetup) {
      _recordDuration(success: true);
      if (!mounted) {
        return;
      }
      unawaited(
        Navigator.of(context).pushNamed(
          AppRouter.scanWifiNetworkPage,
          arguments: ScanWifiNetworkPagePayload(
            device,
            _onWifiSelected,
          ),
        ),
      );
      await _showSuccessAndPop();
      return;
    }

    Pair<String, bool>? res;
    try {
      final topicId = await injector<FFBluetoothService>().keepWifi(device);
      res = Pair<String, bool>(
        topicId,
        true, // indicates that it from onboarding
      );

      final ffDevice = device.toFFBluetoothDevice(
        topicId: res.first,
        deviceId: device.advName,
        branchName: widget.payload.branchName,
      );
      await BluetoothDeviceManager().addDevice(ffDevice);

      _recordDuration(success: true);

      injector<NavigationService>()
          .popUntil(AppRouter.bluetoothDevicePortalPage);

      unawaited(
        injector<NavigationService>().popAndPushNamed(
          AppRouter.bluetoothConnectedDeviceConfig,
          arguments: BluetoothConnectedDeviceConfigPayload(
            isFromOnboarding: true,
          ),
        ),
      );
    } on FFBluetoothResponseError catch (e) {
      if (e is DeviceUpdatingError || e is DeviceVersionCheckFailedError) {
        injector<NavigationService>().goBack();
      }
      final context = injector<NavigationService>().context;
      await UIHelper.showInfoDialog(
        context,
        e.title,
        e.message,
      );
      rethrow;
    } on Exception catch (e) {
      await UIHelper.showInfoDialog(
        context,
        'Error',
        'Failed to skip internet setup: $e',
      );
      rethrow;
    } finally {
      if (res == null) {
        injector<NavigationService>().popUntil(
          AppRouter.bluetoothDevicePortalPage,
        );
        injector<NavigationService>().goBack(result: res);
      } else {
        await _showSuccessAndPop();
      }
    }
  }

  Future<void> _showSuccessAndPop() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _ConnectFF1Status.success;
    });
    await UIHelper.showInfoDialog(
      context,
      'connected_to_ff1_title'.tr(),
      'connected_to_ff1_body'.tr(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _recordDuration({required bool success}) {
    if (_startTime == null) {
      return;
    }
    final duration = DateTime.now().difference(_startTime!);
    final ms = duration.inMilliseconds;
    String bucket;
    if (duration.inSeconds < 5) {
      bucket = '<5s';
    } else if (duration.inSeconds <= 10) {
      bucket = '5-10s';
    } else {
      bucket = '>10s';
    }
    log.info(
      '[ConnectFF1Page] Connection ${success ? "success" : "failure"} '
      'duration=${duration.inSeconds}s (${ms}ms), bucket=$bucket',
    );
  }

  Future<void> _onCancel() async {
    log.info('[ConnectFF1Page] Cancel pressed, disconnecting and popping');
    _stillConnectingTimer?.cancel();
    try {
      await widget.payload.device.disconnect();
    } catch (e) {
      log.info('[ConnectFF1Page] Error while cancelling connection: $e');
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: getDarkEmptyAppBar(),
      backgroundColor: AppColor.primaryBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: LoadingWidget(
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _titleText.tr(),
                      style: theme.textTheme.ppMori700White24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _bodyText.tr(),
                      style: theme.textTheme.ppMori400White14,
                    ),
                  ],
                ),
              ),
              if (_status == _ConnectFF1Status.error) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        text: 'try_again'.tr(),
                        onTap: _startConnectFlow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        text: 'cancel'.tr(),
                        onTap: _onCancel,
                        color: AppColor.white.withOpacity(0.1),
                        textColor: AppColor.white,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                PrimaryButton(
                  text: 'cancel'.tr(),
                  onTap: _onCancel,
                  color: Colors.transparent,
                  textColor: AppColor.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _titleText {
    switch (_status) {
      case _ConnectFF1Status.connecting:
        return 'connecting_to_ff1_title';
      case _ConnectFF1Status.stillConnecting:
        return 'still_connecting_to_ff1_title';
      case _ConnectFF1Status.error:
        return 'could_not_connect_to_ff1_title';
      case _ConnectFF1Status.success:
        return 'connected_to_ff1_title';
    }
  }

  String get _bodyText {
    switch (_status) {
      case _ConnectFF1Status.connecting:
        return 'connecting_to_ff1_body';
      case _ConnectFF1Status.stillConnecting:
        return 'still_connecting_to_ff1_body';
      case _ConnectFF1Status.error:
        return 'could_not_connect_to_ff1_body';
      case _ConnectFF1Status.success:
        return 'connected_to_ff1_body';
    }
  }

  FutureOr<void> _onWifiSelected(WifiPoint accessPoint) async {
    log.info('[ConnectFF1Page] onWifiSelected: $accessPoint');
    final device = widget.payload.device;
    final branchName = widget.payload.branchName;
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

          injector<NavigationService>()
              .popUntil(AppRouter.bluetoothDevicePortalPage);
          unawaited(injector<NavigationService>().popAndPushNamed(
            AppRouter.bluetoothConnectedDeviceConfig,
            arguments: BluetoothConnectedDeviceConfigPayload(
              isFromOnboarding: true,
            ),
          ));
        } else if (error != null) {
          injector<NavigationService>()
            ..popUntil(AppRouter.bluetoothDevicePortalPage);
        }
      },
    );
    injector<NavigationService>()
        .navigateTo(AppRouter.sendWifiCredentialPage, arguments: payload);
  }
}
