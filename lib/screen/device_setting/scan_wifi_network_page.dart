import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/wifi_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:wifi_scan/wifi_scan.dart';

class WifiPoint {
  WifiPoint(this.ssid, {this.isOpenNetwork});

  factory WifiPoint.fromWifiScanResult(String result) {
    // Backward compatibility: if result doesn't have format "ssid|security",
    // treat entire result as SSID and assume it's not an open network
    if (!result.contains('|')) {
      return WifiPoint(result, isOpenNetwork: false);
    }

    final parts = result.split('|');
    final ssid = parts.isNotEmpty ? parts.first : '';
    final security = parts.length > 1 ? parts[1].trim().toUpperCase() : '';
    final isOpenNetwork = security == 'OPEN';
    return WifiPoint(
      ssid,
      isOpenNetwork: isOpenNetwork,
    );
  }

  final String ssid;
  final bool? isOpenNetwork;
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
    var device = widget.payload.device;
    setState(() {
      _isScanning = true;
    });
    try {
      if (device is FFBluetoothDevice && device.remoteID.isEmpty) {
        device = await injector<FFBluetoothService>().scanAndConnect(device);
      } else {
        await injector<FFBluetoothService>().connectToDevice(device);
      }
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
        final accessPoints = result.map(WifiPoint.fromWifiScanResult).toList();
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
    _ssidController.dispose();
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
      appBar: SetupAppBar(
        title: 'select_network'.tr(),
      ),
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Padding(
          padding: ResponsiveLayout.pageEdgeInsets,
          child: KeyboardVisibilityBuilder(
            builder: (context, isKeyboardVisible) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: LayoutConstants.space6 + LayoutConstants.space2,
                    ),
                  ),
                  if (_isScanning) ...[
                    SliverToBoxAdapter(
                      child: Text(
                        'Getting WiFi networks from your FF1. Please wait a moment...',
                        style: AppTypography.body(context).white,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: LayoutConstants.space6),
                    ),
                  ] else ...[
                    if (_accessPoints == null)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.payload.device.isConnected) ...[
                              Text(
                                'Cannot get available networks from your FF1',
                                style:
                                    AppTypography.caption(context).bold.white,
                              ),
                              SizedBox(height: LayoutConstants.space2),
                              Text(
                                'There might be an issue with the WiFi module on your FF1. Please try restarting your FF1 and scan again.',
                                style: AppTypography.body(context).white,
                              ),
                            ] else ...[
                              Text(
                                'Unable to Connect to FF1',
                                style:
                                    AppTypography.caption(context).bold.white,
                              ),
                              SizedBox(height: LayoutConstants.space2),
                              Text(
                                'Connection to the FF1 could not be established',
                                style: AppTypography.body(context).white,
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
                              style: AppTypography.caption(context).bold.white,
                            ),
                            SizedBox(height: LayoutConstants.space4),
                            Text(
                              'There might be an issue with the WiFi module on your FF1. Please try restarting your FF1 and scan again.',
                              style: AppTypography.body(context).white,
                            ),
                          ],
                        ),
                      ),
                    if (_accessPoints == null || _accessPoints!.isEmpty)
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: LayoutConstants.space5),
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
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: LayoutConstants.space10,
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
        Text(
          '''To avoid overloading the BLE connection, only the strongest nearby Wi-Fi networks are shown. '''
          '''If your network isn't listed, try moving the device closer to your Wi-Fi router, or connect manually.''',
          style: AppTypography.body(context).white,
        ),
        SizedBox(
          height: LayoutConstants.space20,
        ),
        ..._accessPoints?.map(
              (e) => itemBuilder(context, e),
            ) ??
            [],
        if (widget.payload.device.isConnected) ...[
          _otherNetworkItem(context),
        ],
      ],
    );
  }

  Widget _otherNetworkItem(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionExpandedWidget(
          header: 'Other network',
          headerStyle: AppTypography.body(context).white,
          withDivider: false,
          isExpandedDefault: false,
          padding: EdgeInsets.zero,
          headerPadding: EdgeInsets.symmetric(
            vertical: LayoutConstants.space5,
          ),
          iconOnUnExpanded: SizedBox.shrink(),
          iconOnExpanded: SizedBox.shrink(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Network name (SSID)',
                style: AppTypography.body(context).white,
              ),
              SizedBox(height: LayoutConstants.space4),
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  hintText: 'Enter wifi network',
                  hintStyle: AppTypography.body(context).white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      LayoutConstants.space2 + LayoutConstants.space1,
                    ),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppColor.primaryBlack,
                  focusColor: AppColor.primaryBlack,
                  filled: true,
                  constraints: BoxConstraints(
                    minHeight:
                        LayoutConstants.minTouchTarget + LayoutConstants.space4,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: LayoutConstants.space6,
                    horizontal: LayoutConstants.space4,
                  ),
                ),
                style: AppTypography.body(context).white,
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _shouldEnableConnectButton = value.trim().isNotEmpty;
                    });
                  }
                },
              ),
              SizedBox(height: LayoutConstants.space6),
              PrimaryButton(
                enabled: _shouldEnableConnectButton,
                onTap: () async {
                  final ssid = _ssidController.text.trim();
                  if (ssid.isEmpty) {
                    return;
                  }
                  await widget.payload.onNetworkSelected(
                    WifiPoint(ssid),
                  );
                },
                text: 'Continue',
              ),
              SizedBox(height: LayoutConstants.space4),
            ],
          ),
        ),
        const Divider(
          color: AppColor.primaryBlack,
        ),
      ],
    );
  }

  Widget itemBuilder(BuildContext context, WifiPoint wifiAccessPoint) {
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
                padding: EdgeInsets.symmetric(
                  vertical: LayoutConstants.space5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      wifiAccessPoint.ssid,
                      style: AppTypography.body(context).white,
                    ),
                    if (!(wifiAccessPoint.isOpenNetwork ?? false))
                      Icon(
                        Icons.lock,
                        color: AppColor.white,
                        size: LayoutConstants.iconSizeMedium,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(
          color: AppColor.primaryBlack,
        ),
      ],
    );
  }
}
