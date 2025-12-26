import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/model/device/ff1_device.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/error/bluetooth_response_error.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gif_view/gif_view.dart';

enum _ConnectFF1Status {
  connecting,
  stillConnecting,
  error,
  success,
  portalIsSet,
}

class ConnectFF1PagePayload {
  ConnectFF1PagePayload({
    required this.device,
    this.ff1Device,
    this.onConnectedSuccess,
    this.onConnectedFailed,
  });

  final BluetoothDevice device;
  final FF1DeviceInfo? ff1Device;
  final FutureOr<void> Function(String branchName)? onConnectedSuccess;
  final FutureOr<void> Function()? onConnectedFailed;
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
  bool _cancelRequested = false;

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
      const Duration(seconds: 15),
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
    _cancelRequested = false;
    _stillConnectingTimer?.cancel();
    _setupStillConnectingTimer();
    if (mounted) {
      setState(() {
        _status = _ConnectFF1Status.connecting;
      });
    } else {
      _status = _ConnectFF1Status.connecting;
    }
    _startTime = DateTime.now();
    log.info('[ConnectFF1Page] Start connecting to FF1');
    try {
      var device = widget.payload.device;
      if (device is FFBluetoothDevice && device.remoteID.isEmpty) {
        log.info(
          '[ConnectFF1Page] Device ${device.name} has empty remoteID, scan and connect',
        );
        device = await injector<FFBluetoothService>()
            .scanAndConnect(device, shouldShowError: false);
      } else {
        await injector<FFBluetoothService>().connectToDevice(
          device,
          shouldShowError: false,
          shouldContinue: () => !_cancelRequested,
        );
      }

      await _handlePostConnect(device);
    } catch (e) {
      if (e is BluetoothConnectCancelledError) {
        log.info('[ConnectFF1Page] Connection cancelled by user');
      } else {
        log.info('[ConnectFF1Page] Error connecting to device: $e');
        _recordDuration(success: false);
        if (mounted) {
          setState(() {
            _status = _ConnectFF1Status.error;
          });
        }
        await widget.payload.onConnectedFailed?.call();
      }
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _handlePostConnect(BluetoothDevice device) async {
    var ff1Device = widget.payload.ff1Device;

    // If device info is not provided, fetch it via get_info command
    if (ff1Device == null) {
      log.info(
          '[ConnectFF1Page] Device info not provided, fetching via get_info');
      try {
        // Add delay to ensure connection is stable and characteristics are discovered
        // Connection state handler already waits 1s, but add extra delay for getInfo
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final getInfoResponse =
            await injector<FFBluetoothService>().getInfo(device);
        ff1Device = getInfoResponse.deviceInfoString.toFF1DeviceInfo;

        log.info(
          '[ConnectFF1Page] Got device info: topicId=${ff1Device.topicId}, '
          'isConnectedToInternet=${ff1Device.isConnectedToInternet}, '
          'branchName=${ff1Device.branchName}, version=${ff1Device.version}',
        );

        // Check version compatibility
        final compatible =
            await injector<VersionService>().checkDeviceVersionCompatibility(
          dBranch: ff1Device.branchName,
          dVersion: ff1Device.version,
          requiredDeviceUpdate: false,
        );
        if (compatible == VersionCompatibilityResult.needUpdateApp) {
          log.info(
            'FF1 version is not compatible with the app. Please update the app.',
          );
          return;
        }
      } catch (e) {
        log.warning('[ConnectFF1Page] Failed to get device info: $e');
        // TODO: Add Get Info Error state
        return;
      }
    }

    final topicId = ff1Device.topicId;
    final branchName = ff1Device.branchName;

    if (!ff1Device.isConnectedToInternet) {
      _recordDuration(success: true);
      if (!mounted) {
        return;
      }
      await _showSuccessAndPop(
        onContinue: () async {
          injector<NavigationService>().goBack();
          await widget.payload.onConnectedSuccess?.call(branchName);
        },
      );
      return;
    }

    if (topicId.isNotEmpty) {
      final ffBluetoothDevice = FFBluetoothDevice(
        name: ff1Device.name,
        remoteID: device.remoteId.str,
        topicId: topicId,
        deviceId: ff1Device.deviceId,
        branchName: branchName,
      );
      // add device to canvas
      await BluetoothDeviceManager().addDevice(ffBluetoothDevice);

      // Hide QR code on device
      unawaited(
        injector<CanvasClientServiceV2>()
            .showPairingQRCode(ffBluetoothDevice, false),
      );

      // Show Portal is Set
      setState(() {
        _status = _ConnectFF1Status.portalIsSet;
      });
      return;
    }

    Pair<String, bool>? res;
    try {
      final topicIdFromKeepWifi =
          await injector<FFBluetoothService>().keepWifi(device);
      res = Pair<String, bool>(
        topicIdFromKeepWifi,
        true, // indicates that it from onboarding
      );

      final ffDevice = device.toFFBluetoothDevice(
        topicId: res.first,
        deviceId: device.advName,
        branchName: branchName,
      );
      await BluetoothDeviceManager().addDevice(ffDevice);

      _recordDuration(success: true);

      injector<NavigationService>().popUntil(AppRouter.startSetupFF1Page);

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
          AppRouter.startSetupFF1Page,
        );
        injector<NavigationService>().goBack(result: res);
      } else {
        await _showSuccessAndPop();
      }
    }
  }

  Future<void> _showSuccessAndPop({VoidCallback? onContinue}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _ConnectFF1Status.success;
    });

    await Future<void>.delayed(Duration.zero);
    if (mounted) {
      if (onContinue != null) {
        onContinue();
      } else {
        Navigator.of(context).pop();
      }
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
      _cancelRequested = true;
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
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_status != _ConnectFF1Status.error) ...[
                      if (_status == _ConnectFF1Status.portalIsSet)
                        Image.asset(
                          'assets/images/ff_logo.png',
                          width: 139,
                          height: 92.67,
                        )
                      else
                        GifView.asset(
                          'assets/images/loading.gif',
                          width: 139,
                          height: 92.67,
                          frameRate: 12,
                        ),
                      const SizedBox(height: 85),
                    ] else ...[
                      const Icon(
                        Icons.error,
                        size: 48,
                        color: AppColor.feralFileLightBlue,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Align(
                      alignment: _status != _ConnectFF1Status.error
                          ? Alignment.centerLeft
                          : Alignment.center,
                      child: Column(
                        crossAxisAlignment: _status != _ConnectFF1Status.error
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
                        children: [
                          Text(
                            _titleText.tr(),
                            style: theme.textTheme.h3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _bodyText.tr(),
                            style: AppTypography.body(context).white,
                          ),
                          if (_status == _ConnectFF1Status.portalIsSet) ...[
                            const SizedBox(height: 20),
                            PrimaryButton(
                              onTap: () async {
                                unawaited(
                                  injector<NavigationService>().navigateTo(
                                    AppRouter.bluetoothConnectedDeviceConfig,
                                    arguments:
                                        BluetoothConnectedDeviceConfigPayload(
                                      isFromOnboarding: true,
                                    ),
                                  ),
                                );
                              },
                              text: 'Go to Settings',
                            ),
                          ],
                        ],
                      ),
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
                        color: AppColor.white,
                        textColor: AppColor.primaryBlack,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        text: 'cancel'.tr(),
                        onTap: _onCancel,
                        color: AppColor.white,
                        textColor: AppColor.primaryBlack,
                      ),
                    ),
                  ],
                ),
              ] else if (_status != _ConnectFF1Status.portalIsSet) ...[
                PrimaryButton(
                  text: 'cancel'.tr(),
                  onTap: _onCancel,
                  color: AppColor.white,
                  textColor: AppColor.primaryBlack,
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
      case _ConnectFF1Status.portalIsSet:
        return 'portal_is_set_title';
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
      case _ConnectFF1Status.portalIsSet:
        return 'portal_is_set_body';
    }
  }
}
