import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/nft_collection/utils/list_extentions.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_state.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/connect_ff1_page.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HandleBluetoothDeviceScanDeeplinkScreenPayload {
  HandleBluetoothDeviceScanDeeplinkScreenPayload({
    required this.deeplink,
    this.onFinish,
  });

  final String deeplink;
  final Function? onFinish;
}

class HandleBluetoothDeviceScanDeeplinkScreen extends StatefulWidget {
  const HandleBluetoothDeviceScanDeeplinkScreen({
    required this.payload,
    super.key,
  });

  final HandleBluetoothDeviceScanDeeplinkScreenPayload payload;

  @override
  State<HandleBluetoothDeviceScanDeeplinkScreen> createState() =>
      HandleBluetoothDeviceScanDeeplinkScreenState();
}

class HandleBluetoothDeviceScanDeeplinkScreenState
    extends State<HandleBluetoothDeviceScanDeeplinkScreen>
    with WidgetsBindingObserver {
  late String _deeplink;
  bool _isScanning = false;
  bool _portalIsSet = false;
  BluetoothDevice? _resultDevice;
  final bloc = injector<BluetoothConnectBloc>();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _deeplink = widget.payload.deeplink;
    if (bloc.state.bluetoothAdapterState == BluetoothAdapterState.on) {
      _handleBluetoothConnectDeeplink(
        context,
        _deeplink,
        onFinish: widget.payload.onFinish,
      );
    }
    injector<FFBluetoothService>().listenForAdapterState();
  }

  List<String> getDataFromLink(String link) {
    final prefix = Constants.bluetoothConnectDeepLinks.firstWhereOrNull(
          (prefix) => link.startsWith(prefix),
        ) ??
        '';
    String path = link.replaceFirst(prefix, '');
    if (path.startsWith('/')) {
      path = path.substring(1); // Remove leading slash if present
    }
    // Decode percent-encoded characters (e.g. '%7C' for '|') before splitting.
    // This fixes a case on some Android camera apps (e.g., Google Pixel default camera)
    // where the scanned deeplink path includes encoded separators.
    final encodedPath = Uri.decodeFull(path);
    final data = encodedPath.split('|');
    // Dont remove empty elements, as they are used to indicate the absence of a value
    // ..removeWhere(
    //   (element) => element.isEmpty,
    // );
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getDarkEmptyAppBar(),
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: BlocConsumer<BluetoothConnectBloc, BluetoothConnectState>(
          bloc: injector<BluetoothConnectBloc>(),
          builder: (context, state) {
            final isBluetoothEnabled =
                state.bluetoothAdapterState == BluetoothAdapterState.on;

            if (!isBluetoothEnabled) {
              return bluetoothNotAvailable(context);
            }

            if (_isScanning) {
              return scanning(context);
            }

            if (_portalIsSet) {
              return portalIsSet(context);
            }

            if (_resultDevice == null) {
              return deviceNotFound(context);
            }

            return Container();
          },
          listener: (context, state) {
            if (state.bluetoothAdapterState == BluetoothAdapterState.on) {
              _handleBluetoothConnectDeeplink(
                context,
                _deeplink,
                onFinish: widget.payload.onFinish,
              );
            }
          },
        ),
      ),
    );
  }

  Widget bluetoothNotAvailable(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error,
          size: 48,
          color: AppColor.feralFileLightBlue,
        ),
        const SizedBox(height: 16),
        Text(
          'Bluetooth is required for setup. Please turn it on to continue.',
          style: Theme.of(context).textTheme.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          text: 'Open Bluetooth Settings',
          onTap: () {
            injector<NavigationService>().openBluetoothSettings();
          },
        ),
      ],
    );
  }

  Widget scanning(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          'assets/images/ff_logo.png',
          width: 139,
          height: 92.67,
        ),
        const SizedBox(height: 85),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connecting via Bluetooth...',
                style: Theme.of(context).textTheme.h3,
              ),
              const SizedBox(height: 20),
              Text(
                'Keep your phone near FF1 and remain on this screen',
                style: Theme.of(context).textTheme.small,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget portalIsSet(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset(
          'assets/images/ff_logo.png',
          width: 139,
          height: 92.67,
        ),
        const SizedBox(height: 85),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The FF1 is All Set',
                style: Theme.of(context).textTheme.h3,
              ),
              const SizedBox(height: 20),
              Text(
                'Your FF1 is already set up and connected. You can head to settings to make changes or check the status.',
                style: Theme.of(context).textTheme.small,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                onTap: () async {
                  unawaited(
                    injector<NavigationService>().navigateTo(
                      AppRouter.bluetoothConnectedDeviceConfig,
                      arguments: BluetoothConnectedDeviceConfigPayload(
                        isFromOnboarding: true,
                      ),
                    ),
                  );

                  try {
                    await widget.payload.onFinish?.call();
                  } catch (e) {
                    log.info('Failed to call onFinish: $e');
                  }
                },
                text: 'Go to Settings',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget deviceNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error,
            size: 48,
            color: AppColor.feralFileLightBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'FF1 not found',
            style: Theme.of(context).textTheme.h3,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Try again',
            onTap: () {
              _handleBluetoothConnectDeeplink(
                context,
                _deeplink,
                onFinish: widget.payload.onFinish,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleBluetoothConnectDeeplink(
    BuildContext context,
    String link, {
    Function? onFinish,
  }) async {
    if (_isScanning) {
      return;
    }
    setState(() {
      _isScanning = true;
    });
    final data = getDataFromLink(link);
    final deviceName = data.firstOrNull;

    final topicId = data.atIndexOrNull(1);
    final isConnectedToInternet = data.atIndexOrNull(2) == 'true';
    final branchNameRaw = data.atIndexOrNull(3);

    final branchName = branchNameRaw ?? DeviceReleaseBranch.release.name;
    final version = data.atIndexOrNull(4);

    final compatible = await injector<VersionService>()
        .checkDeviceVersionCompatibility(
            dBranch: branchName,
            dVersion: version,
            requiredDeviceUpdate: false);
    if (compatible == VersionCompatibilityResult.needUpdateApp) {
      log.info(
        'FF1 version is not compatible with the app. Please update the app.',
      );
      return;
    }

    BluetoothDevice? resultDevice;

    if (topicId != null &&
        topicId.isNotEmpty &&
        isConnectedToInternet == true) {
      log.info(
        'FF1 is already setup and connected to internet. Skip scanning and wifi setup.',
      );
      final ffDevice = FFBluetoothDevice(
          name: deviceName ?? 'FF1',
          remoteID: '',
          topicId: topicId,
          deviceId: deviceName ?? 'FF1',
          branchName: branchName);
      // add device to canvas
      await BluetoothDeviceManager().addDevice(ffDevice);

      // Hide QR code on device
      unawaited(
        injector<CanvasClientServiceV2>().showPairingQRCode(ffDevice, false),
      );

      setState(() {
        _isScanning = false;
        _portalIsSet = true;
      });
    } else {
      log.info('Starting scan for FF1: $deviceName');
      resultDevice = await injector<FFBluetoothService>().scanForName(
        timeout: const Duration(seconds: 15),
        name: deviceName ?? 'FF1',
      );

      if (context.mounted) {
        setState(() {
          _isScanning = false;
          _resultDevice = resultDevice;
        });
      }
      if (resultDevice != null) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        unawaited(injector<ConfigurationService>().setBetaTester(true));
        injector<SubscriptionBloc>().add(GetSubscriptionEvent());

        if (topicId != null && topicId.isNotEmpty) {
          // add device to canvas
          final device = resultDevice.toFFBluetoothDevice(
            topicId: topicId,
            deviceId: resultDevice.advName,
            branchName: branchName,
          );
          await BluetoothDeviceManager().addDevice(
            device,
          );
        }

        // await injector<NavigationService>().navigateTo(
        //   AppRouter.bluetoothDevicePortalPage,
        //   arguments: BluetoothDevicePortalPagePayload(
        //     device: resultDevice,
        //     canSkipNetworkSetup: isConnectedToInternet,
        //     branchName: branchName,
        //   ),
        // );

        unawaited(
          injector<NavigationService>().navigateTo(
            AppRouter.connectFF1,
            arguments: ConnectFF1PagePayload(
              device: resultDevice,
              canSkipNetworkSetup: isConnectedToInternet,
              branchName: branchName,
              onConnectedSuccess: () async {
                await injector<NavigationService>().navigateTo(
                  AppRouter.scanWifiNetworkPage,
                  arguments: ScanWifiNetworkPagePayload(
                    resultDevice!,
                    (accessPoint) =>
                        _onWifiSelected(accessPoint, resultDevice!, branchName),
                  ),
                );
                await resultDevice.disconnect();
              },
            ),
          ),
        );

        log.info(
            'Bluetooth device setup completed. Disconnecting from FF1: ${resultDevice.name}');
        unawaited(_resultDevice?.disconnect());
      } else {
        log.info('FF1 not found after scanning: $deviceName');
      }

      try {
        await onFinish?.call();
      } catch (e) {
        log.info('Failed to call onFinish: $e');
      }
    }
  }

  FutureOr<void> _onWifiSelected(
      WifiPoint accessPoint, BluetoothDevice device, String branchName) async {
    log.info('[ConnectFF1Page] onWifiSelected: $accessPoint');
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
              .popUntil(AppRouter.startSetupFF1Page);
          unawaited(injector<NavigationService>().popAndPushNamed(
            AppRouter.bluetoothConnectedDeviceConfig,
            arguments: BluetoothConnectedDeviceConfigPayload(
              isFromOnboarding: true,
            ),
          ));
        } else if (error != null) {
          injector<NavigationService>()
            ..popUntil(AppRouter.startSetupFF1Page);
          injector<NavigationService>().goBack();
        }
      },
    );
    injector<NavigationService>()
        .navigateTo(AppRouter.sendWifiCredentialPage, arguments: payload);
  }
}
