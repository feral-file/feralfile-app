import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/wifi_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/important_note_view.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiPoint {
  WifiPoint(this.ssid);

  final String ssid;
}

class ScanWifiNetworkPagePayload {
  ScanWifiNetworkPagePayload(this.device, this.onNetworkSelected);

  final FutureOr<void> Function(WifiPoint wifiAccessPoint) onNetworkSelected;
  final BluetoothDevice device;
}

class ScanWifiNetworkPage extends StatefulWidget {
  const ScanWifiNetworkPage({required this.payload, super.key});

  final ScanWifiNetworkPagePayload payload;

  @override
  State<ScanWifiNetworkPage> createState() => ScanWifiNetworkPageState();
}

class ScanWifiNetworkPageState extends State<ScanWifiNetworkPage>
    with RouteAware {
  List<WifiPoint>? _accessPoints;
  StreamSubscription<List<WiFiAccessPoint>>? _subscription;
  final TextEditingController _ssidController = TextEditingController();
  bool _shouldEnableConnectButton = false;

  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() {
    _isScanning = false;
    super.didPopNext();
  }

  Future<void> _startScan() async {
    final device = widget.payload.device;
    setState(() {
      _isScanning = true;
    });
    try {
      await injector<FFBluetoothService>().connectToDevice(device);
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      return;
    }
    const timeout = Duration(seconds: 15);

    // check platform support and necessary requirements
    await WifiHelper.scanWifiNetwork(
      device: device,
      timeout: timeout,
      onResultScan: (result) {
        final accessPoints = result.map(WifiPoint.new).toList();
        if (mounted) {
          setState(() {
            _accessPoints = _filterUniqueSSIDs(accessPoints);
          });
        }
      },
      shouldStop: (result) {
        return !_isScanning;
      },
    );
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  List<WifiPoint> _filterUniqueSSIDs(List<WifiPoint> scanResults) {
    final uniqueNetworks = <String, WifiPoint>{};
    for (final scanResult in scanResults) {
      uniqueNetworks[scanResult.ssid] = scanResult;
    }
    uniqueNetworks.removeWhere((key, value) => key.isEmpty);
    return uniqueNetworks.values.toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    log.info(
      'ScanWifiNetworkPage: dispose called, disconnecting from device ${widget.payload.device.name}',
    );
    widget.payload.device.disconnect();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getBackAppBar(
        context,
        onBack: () {
          Navigator.of(context).pop();
        },
        title: 'select_network'.tr(),
        isWhite: false,
      ),
      backgroundColor: AppColor.primaryBlack,
      body: SafeArea(
        child: Padding(
          padding: ResponsiveLayout.pageEdgeInsets,
          child: KeyboardVisibilityBuilder(
            builder: (context, isKeyboardVisible) {
              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 30,
                    ),
                  ),
                  if (_isScanning) ...[
                    SliverToBoxAdapter(
                      child: Text(
                        'Getting WiFi networks from your FF1. Please wait a moment...',
                        style: Theme.of(context).textTheme.ppMori400White14,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ] else ...[
                    if (_accessPoints == null)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.payload.device.isConnected) ...[
                              Text(
                                'Cannot get available networks from your FF1',
                                style: Theme.of(context)
                                    .textTheme
                                    .ppMori700White14,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'There might be an issue with the WiFi module on your FF1. Please try restarting your FF1 and scan again.',
                                style: Theme.of(context)
                                    .textTheme
                                    .ppMori400White14,
                              ),
                            ] else ...[
                              Text(
                                'Unable to Connect to FF1',
                                style: Theme.of(context)
                                    .textTheme
                                    .ppMori700White14,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Connection to the FF1 could not be established',
                                style: Theme.of(context)
                                    .textTheme
                                    .ppMori400White14,
                              ),
                            ],
                          ],
                        ),
                      )
                    else if (_accessPoints!.isEmpty)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No wifi networks found by FF1',
                              style:
                                  Theme.of(context).textTheme.ppMori700White14,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'There might be an issue with the WiFi module on your FF1. Please try restarting your FF1 and scan again.',
                              style:
                                  Theme.of(context).textTheme.ppMori400White14,
                            ),
                          ],
                        ),
                      ),
                    if (_accessPoints == null || _accessPoints!.isEmpty)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            PrimaryButton(
                              onTap: () async {
                                await _startScan();
                              },
                              text: 'retry'.tr(),
                            ),
                          ],
                        ),
                      ),
                  ],
                  ...[
                    if (_accessPoints?.isNotEmpty ?? false)
                      SliverToBoxAdapter(child: _listWifiView(context)),
                    if ((!_isScanning ||
                            (_accessPoints?.isNotEmpty ?? false)) &&
                        widget.payload.device.isConnected) ...[
                      SliverToBoxAdapter(
                        child: _enterWifiManuallyView(context),
                      ),
                    ],
                  ],
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 40,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _listWifiView(BuildContext context) {
    return Column(
      children: [
        ImportantNoteView(
          note:
              '''To avoid overloading the BLE connection, only the strongest nearby Wi-Fi networks are shown. If your network isn't listed, try moving the device closer to your Wi-Fi router, or connect manually.''',
          title: 'Showing Strongest Networks Only',
          backgroundColor: AppColor.primaryBlack,
          borderColor: AppColor.white,
          noteStyle: Theme.of(context).textTheme.ppMori400White14,
          titleStyle: Theme.of(context).textTheme.ppMori700White14,
        ),
        const SizedBox(
          height: 16,
        ),
        ..._accessPoints?.map(
              (e) => itemBuilder(context, e),
            ) ??
            [],
      ],
    );
  }

  Widget _enterWifiManuallyView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Or enter your Wi-Fi name (SSID) below to connect manually.',
          style: Theme.of(context).textTheme.ppMori400White14,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ssidController,
          decoration: InputDecoration(
            // border radius 10
            hintText: 'Enter wifi network',
            hintStyle: Theme.of(context).textTheme.ppMori400White14,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: AppColor.auGreyBackground,
            focusColor: AppColor.auGreyBackground,
            filled: true,
            constraints: const BoxConstraints(minHeight: 60),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 24,
              horizontal: 16,
            ),
          ),
          style: Theme.of(context).textTheme.ppMori400White14,
          onChanged: (value) {
            if (mounted) {
              setState(() {
                _shouldEnableConnectButton = value.trim().isNotEmpty;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          enabled: _shouldEnableConnectButton,
          onTap: () async {
            final ssid = _ssidController.text.trim();
            if (ssid.isEmpty) {
              return;
            }
            await widget.payload.onNetworkSelected(WifiPoint(ssid));
          },
          text: 'Connect',
        ),
      ],
    );
  }

  Widget itemBuilder(BuildContext context, WifiPoint wifiAccessPoint) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            await widget.payload.onNetworkSelected(wifiAccessPoint);
          },
          child: SizedBox(
            width: double.infinity,
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  wifiAccessPoint.ssid,
                  style: theme.textTheme.ppMori400White14,
                ),
              ),
            ),
          ),
        ),
        const Divider(
          color: AppColor.auGreyBackground,
        ),
      ],
    );
  }
}
