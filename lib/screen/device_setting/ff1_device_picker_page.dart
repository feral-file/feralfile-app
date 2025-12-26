import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/bluetooth_connect/bluetooth_connect_state.dart';
import 'package:autonomy_flutter/screen/device_setting/start_setup_ff1_page.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:gif_view/gif_view.dart';

class FF1DevicePickerPage extends StatefulWidget {
  const FF1DevicePickerPage({super.key});

  @override
  State<FF1DevicePickerPage> createState() => _FF1DevicePickerPageState();
}

class _FF1DevicePickerPageState extends State<FF1DevicePickerPage> {
  final List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  String? _errorMessage;
  final bloc = injector<BluetoothConnectBloc>();

  @override
  void initState() {
    super.initState();
    if (bloc.state.bluetoothAdapterState == BluetoothAdapterState.on) {
      _startScan();
    }

    injector<FFBluetoothService>().listenForAdapterState();
  }

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _discoveredDevices.clear();
    });

    try {
      final bluetoothService = injector<FFBluetoothService>();

      if (!bluetoothService.isBluetoothOn) {
        throw Exception('Bluetooth is not enabled');
      }

      log.info('[FF1DevicePickerPage] Starting BLE scan for FF1 devices');

      await bluetoothService.startScan(
        timeout: const Duration(seconds: 5),
        onData: (devices) async {
          if (!mounted) {
            return false;
          }

          if (devices.isNotEmpty) {
            setState(() {
              for (final device in devices) {
                final existingIndex = _discoveredDevices.indexWhere(
                  (d) => d.remoteId == device.remoteId,
                );

                if (existingIndex == -1) {
                  log.info(
                    '[FF1DevicePickerPage] Found FF1 device: ${device.advName} (${device.remoteId.str})',
                  );
                  _discoveredDevices.add(device);
                } else {
                  // Update existing device
                  _discoveredDevices[existingIndex] = device;
                }
              }
            });
          }

          // Don't stop scan early - let it run for full timeout to find all devices
          return false;
        },
        onError: (dynamic error) {
          log.warning('[FF1DevicePickerPage] Scan error: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Scan error: $error';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isScanning = false;
        });

        // If exactly one device found after scan completes, auto-navigate
        if (_discoveredDevices.length == 1) {
          _navigateToStartSetupPage(_discoveredDevices.first);
        }
      }
    } catch (e) {
      log.warning('[FF1DevicePickerPage] Failed to start scan: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = 'Failed to scan: $e';
        });
      }
    }
  }

  Future<void> _stopScan() async {
    _isScanning = false;
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      log.warning('[FF1DevicePickerPage] Error stopping scan: $e');
    }
  }

  void _handleDeviceSelected(BluetoothDevice device) {
    log.info(
      '[FF1DevicePickerPage] Selected device: ${device.advName}',
    );
    _navigateToStartSetupPage(device);
  }

  void _navigateToStartSetupPage(BluetoothDevice device) {
    log.info(
      '[FF1DevicePickerPage] Navigating to startSetupFF1Page with device: ${device.advName}',
    );
    injector<NavigationService>().goBack();
    injector<NavigationService>().navigateTo(
      AppRouter.startSetupFF1Page,
      arguments: BluetoothDevicePortalPagePayload(
        selectedDevice: device,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SetupAppBar(
        title: 'Find FF1',
      ),
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.setupPageHorizontal,
          ),
          child: BlocConsumer<BluetoothConnectBloc, BluetoothConnectState>(
            bloc: bloc,
            builder: (context, state) {
              final isBluetoothEnabled =
                  state.bluetoothAdapterState == BluetoothAdapterState.on;

              if (!isBluetoothEnabled) {
                return _bluetoothNotAvailableView();
              }

              // Show scanning view while scanning
              if (_isScanning) {
                return _scanningDevicesView();
              }

              // After scan completed, show results
              if (_errorMessage != null && _discoveredDevices.isEmpty) {
                return _errorView();
              }

              if (_discoveredDevices.isEmpty) {
                return _emptyView();
              }

              // Show device list after scan completed
              return _devicePickerView();
            },
            listener: (context, state) {
              if (state.bluetoothAdapterState == BluetoothAdapterState.on &&
                  !_isScanning &&
                  _discoveredDevices.isEmpty) {
                _startScan();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _bluetoothNotAvailableView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          size: LayoutConstants.iconSizeLarge * 2,
          color: AppColor.feralFileLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Bluetooth is required for setup. Please turn it on to continue.',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Open Bluetooth Settings',
          onTap: () {
            injector<NavigationService>().openBluetoothSettings();
          },
        ),
      ],
    );
  }

  Widget _scanningDevicesView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GifView.asset(
          'assets/images/loading.gif',
          width: 139,
          height: 92.67,
          frameRate: 12,
        ),
        const SizedBox(height: 85),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Searching for nearby FF1 devices...',
                style: AppTypography.h2(context).white,
              ),
              SizedBox(height: LayoutConstants.space5),
              Text(
                'Keep your phone near FF1 and remain on this screen',
                style: AppTypography.body(context).white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          size: LayoutConstants.iconSizeLarge * 2,
          color: AppColor.feralFileLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Could not find FF1',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          _errorMessage ?? 'Please make sure FF1 is powered on and nearby',
          style: AppTypography.body(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Try again',
          onTap: _startScan,
          color: PrimitivesTokens.colorsLightBlue,
          textColor: PrimitivesTokens.colorsBlack,
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }

  Widget _emptyView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.bluetooth_searching,
          size: LayoutConstants.iconSizeLarge * 2,
          color: PrimitivesTokens.colorsLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'No FF1 devices found',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Make sure FF1 is powered on and nearby, then try again',
          style: AppTypography.body(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Try again',
          onTap: _startScan,
          color: PrimitivesTokens.colorsLightBlue,
          textColor: PrimitivesTokens.colorsBlack,
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }

  Widget _devicePickerView() {
    final devices = _discoveredDevices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: LayoutConstants.space16),
        Text(
          'Select the FF1 you want to set up',
          style: AppTypography.body(context).white,
        ),
        SizedBox(height: LayoutConstants.space5),
        Expanded(
          child: ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];

              return Column(
                children: [
                  _DeviceItem(
                    device: device,
                    onTap: () {
                      _handleDeviceSelected(device);
                    },
                  ),
                  if (index != devices.length - 1)
                    SizedBox(height: LayoutConstants.space3),
                ],
              );
            },
          ),
        ),
        SizedBox(height: LayoutConstants.space4),
        Center(
          child: TextButton(
            onPressed: _startScan,
            child: Text(
              "Don't see your device? Scan again",
              style: AppTypography.body(context).white.underline,
            ),
          ),
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }
}

class _DeviceItem extends StatelessWidget {
  const _DeviceItem({
    required this.device,
    required this.onTap,
  });

  final BluetoothDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = device.advName.isNotEmpty ? device.advName : 'FF1';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(LayoutConstants.space3),
        decoration: BoxDecoration(
          color: PrimitivesTokens.colorsDarkGrey,
          border: Border.all(
            color: PrimitivesTokens.colorsGrey,
          ),
          borderRadius: BorderRadius.circular(LayoutConstants.space3),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bluetooth,
              color: PrimitivesTokens.colorsGrey,
              size: LayoutConstants.iconSizeMedium,
            ),
            SizedBox(width: LayoutConstants.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.body(context).white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
