import 'dart:async';
import 'dart:math';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/device_status.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/screen/device_setting/device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/screen/playlists/edit_playlist/widgets/text_name_playlist.dart';
import 'package:autonomy_flutter/service/bluetooth_notification_service.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/device_realtime_metric_helper.dart';
import 'package:autonomy_flutter/util/inapp_notifications.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/loading.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/tappable_forward_row.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ScreenOrientation {
  landscape,
  landscapeReverse,
  portrait,
  portraitReverse;

  String get name {
    switch (this) {
      case ScreenOrientation.landscape:
        return 'landscape';
      case ScreenOrientation.landscapeReverse:
        return 'landscapeReverse';
      case ScreenOrientation.portrait:
        return 'portrait';
      case ScreenOrientation.portraitReverse:
        return 'portraitReverse';
    }
  }

  static ScreenOrientation fromString(String value) {
    switch (value) {
      case 'landscape':
      case 'normal':
        return ScreenOrientation.landscape;
      case 'landscapeReverse':
      case 'inverted':
        return ScreenOrientation.landscapeReverse;
      case 'portrait':
      case 'left':
        return ScreenOrientation.portrait;
      case 'portraitReverse':
      case 'right':
        return ScreenOrientation.portraitReverse;
      default:
        throw ArgumentError('Invalid screen orientation: $value');
    }
  }
}

class BluetoothConnectedDeviceConfigPayload {
  BluetoothConnectedDeviceConfigPayload({
    this.isFromOnboarding = false,
  });

  final bool isFromOnboarding;
}

class BluetoothConnectedDeviceConfig extends StatefulWidget {
  const BluetoothConnectedDeviceConfig({required this.payload, super.key});

  final BluetoothConnectedDeviceConfigPayload payload;

  @override
  State<BluetoothConnectedDeviceConfig> createState() =>
      BluetoothConnectedDeviceConfigState();
}

class BluetoothConnectedDeviceConfigState
    extends State<BluetoothConnectedDeviceConfig>
    with
        RouteAware,
        WidgetsBindingObserver,
        AfterLayoutMixin<BluetoothConnectedDeviceConfig> {
  DeviceStatus? deviceStatus;
  late FFBluetoothDevice selectedDevice;
  Timer? _connectionStatusTimer;

  bool _isBLEDeviceConnected = false;

  NotificationCallback? cb;

  // Add performance metrics tracking
  final List<FlSpot> _cpuPoints = [];
  final List<FlSpot> _memoryPoints = [];
  final List<FlSpot> _gpuPoints = [];
  Timer? _metricsUpdateTimer;

  final int _maxDataPoints = 20;

  // Add temperature metrics tracking
  final List<FlSpot> _cpuTempPoints = [];
  final List<FlSpot> _gpuTempPoints = [];

  // Add FPS metrics tracking
  final List<FlSpot> _fpsPoints = [];

  DeviceRealtimeMetrics? _latestMetrics;

  StreamSubscription<DeviceRealtimeMetrics>? _metricsStreamSubscription;

  StreamSubscription<FGBGType>? _fgbgSubscription;

  bool _isShowingQRCode = false;

  double _minPerformanceValue = 0;
  double _maxPerformanceValue = 100;

  double _minTemperatureValue = 0;
  double _maxTemperatureValue = 100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    selectedDevice = BluetoothDeviceManager().castingBluetoothDevice!;
    deviceStatus = BluetoothDeviceManager().castingDeviceStatus.value;
    BluetoothDeviceManager()
        .castingDeviceStatus
        .addListener(_bluetoothDeviceStatusListener);
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (widget.payload.isFromOnboarding) {
      // If this screen is opened from onboarding, we don't need to enable metrics streaming
      return;
    }
    _enableMetricsStreaming();
    _fgbgSubscription =
        FGBGEvents.instance.stream.listen(_handleForeBackground);
  }

  void _handleForeBackground(FGBGType event) {
    if (event == FGBGType.foreground) {
      _enableMetricsStreaming();
    } else {
      _stopMetricsStreaming();
    }
  }

  void _bluetoothDeviceStatusListener() {
    final status = BluetoothDeviceManager().castingDeviceStatus.value;
    if (mounted) {
      setState(() {
        this.deviceStatus = status;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _connectionStatusTimer?.cancel();
    _metricsUpdateTimer?.cancel();
    _metricsStreamSubscription?.cancel();
    BluetoothDeviceManager()
        .castingDeviceStatus
        .removeListener(_bluetoothDeviceStatusListener);
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _stopMetricsStreaming();
    _fgbgSubscription?.cancel();
    super.dispose();
  }

  @override
  void didPushNext() {
    // Called when another route has been pushed on top of this one
    super.didPushNext();
  }

  @override
  void didPopNext() {
    // Called when coming back to this route
    super.didPopNext();
    // Re-enable metrics streaming when returning to this screen
    // _enableMetricsStreaming();
  }

  @override
  Widget build(BuildContext context) {
    final name = selectedDevice.name;
    return Scaffold(
      appBar: getCustomBackAppBar(
        context,
        title: name == null
            ? Text('configure_device'.tr())
            : FFTextName(
                title: name,
                onSubmit: (String newName) async {
                  final device = selectedDevice!;
                  final newDevice =
                      await BluetoothDeviceManager().updateDeviceName(
                    device,
                    newName,
                  );
                  setState(() {
                    selectedDevice = newDevice;
                  });
                },
              ),
        actions: widget.payload.isFromOnboarding
            ? []
            : [
                _buildDeviceSwitcher(context),
                BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
                  bloc: injector<CanvasDeviceBloc>(),
                  buildWhen: (previous, current) {
                    return previous.isDeviceAlive(selectedDevice) !=
                        current.isDeviceAlive(selectedDevice);
                  },
                  builder: (context, state) {
                    return GestureDetector(
                      onTap: () {
                        _showOption(context, state);
                      },
                      child: SvgPicture.asset(
                        'assets/images/more_circle.svg',
                        width: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColor.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    );
                  },
                ),
              ],
      ),
      backgroundColor: AppColor.primaryBlack,
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    return Stack(
      children: [
        _deviceConfig(context),
        if (widget.payload.isFromOnboarding && !_isBLEDeviceConnected)
          Positioned.fill(
            child: BlocConsumer<CanvasDeviceBloc, CanvasDeviceState>(
                bloc: injector<CanvasDeviceBloc>(),
                listener: (context, state) {
                  final isDeviceAlive = state.isDeviceAlive(selectedDevice!);
                  if (mounted && !_isBLEDeviceConnected && isDeviceAlive) {
                    setState(() {
                      _isBLEDeviceConnected = isDeviceAlive;
                    });
                  }
                },
                builder: (context, state) {
                  final isDeviceAlive = state.isDeviceAlive(selectedDevice!);
                  return AnimatedOpacity(
                    opacity: isDeviceAlive ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: LoadingWidget(
                      backgroundColor: Colors.black.withOpacity(0.8),
                      text: 'FF1 is getting ready',
                    ),
                  );
                }),
          ),
        if (widget.payload.isFromOnboarding)
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: PrimaryAsyncButton(
              onTap: () async {
                injector<NavigationService>().popUntilHome();
              },
              text: 'finish'.tr(),
              color: AppColor.white,
            ),
          ),
      ],
    );
  }

  Widget _deviceConfig(BuildContext context) {
    final isFromOnboarding = widget.payload.isFromOnboarding;
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      builder: (context, state) {
        final isBLEDeviceConnected =
            state.isDeviceAlive(selectedDevice!) && deviceStatus != null;
        return Padding(
          padding: EdgeInsets.zero,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).top + 32,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                  child: _displayOrientation(context),
                ),
              ),
              const SliverToBoxAdapter(
                child: Divider(
                  color: AppColor.auGreyBackground,
                  thickness: 1,
                  height: 40,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                  child: _canvasSetting(context),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 20,
                ),
              ),
              const SliverToBoxAdapter(
                child: Divider(
                  color: AppColor.auGreyBackground,
                  thickness: 1,
                  height: 1,
                ),
              ),
              if (!isFromOnboarding) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                    child: _wifiConfig(context),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Divider(
                    color: AppColor.auGreyBackground,
                    thickness: 1,
                    height: 1,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 20,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                    child: _deviceInfo(context),
                  ),
                ),

                // Add performance monitoring section
                const SliverToBoxAdapter(
                  child: Divider(
                    color: AppColor.auGreyBackground,
                    thickness: 1,
                    height: 40,
                  ),
                ),
                if (isBLEDeviceConnected) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                      child: _performanceMonitoring(context),
                    ),
                  ),

                  // Temperature monitoring section
                  const SliverToBoxAdapter(
                    child: Divider(
                      color: AppColor.auGreyBackground,
                      thickness: 1,
                      height: 40,
                    ),
                  ),
                ],
                if (isBLEDeviceConnected) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: ResponsiveLayout.pageHorizontalEdgeInsets,
                      child: _temperatureMonitoring(context),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Divider(
                      color: AppColor.auGreyBackground,
                      thickness: 1,
                      height: 40,
                    ),
                  ),
                ],
              ],
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 80,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _displayOrientationPreview(ScreenOrientation? screenOrientation) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.auGreyBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      height: 200,
      child: Center(
        child: _displayOrientationPreviewImage(
          screenOrientation,
        ),
      ),
    );
  }

  Widget _displayOrientationPreviewImage(ScreenOrientation? screenOrientation) {
    if (screenOrientation == null) {
      return const SizedBox.shrink();
    }
    switch (screenOrientation) {
      case ScreenOrientation.landscape:
        return SvgPicture.asset('assets/images/landscape.svg', width: 150);
      case ScreenOrientation.landscapeReverse:
        return RotatedBox(
          quarterTurns: 2,
          child: SvgPicture.asset(
            'assets/images/landscape.svg',
            width: 150,
          ),
        );
      case ScreenOrientation.portrait:
        return SvgPicture.asset(
          'assets/images/portrait.svg',
          height: 150,
        );
      case ScreenOrientation.portraitReverse:
        return RotatedBox(
          quarterTurns: 2,
          child: SvgPicture.asset(
            'assets/images/portrait.svg',
            height: 150,
          ),
        );
    }
  }

  Widget _displayOrientation(BuildContext context) {
    final blDevice = selectedDevice!;
    return BlocConsumer<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      listener: (context, _) {},
      buildWhen: (previous, current) {
        return previous.isDeviceAlive(blDevice) !=
            current.isDeviceAlive(blDevice);
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'display_orientation'.tr(),
              style: Theme.of(context).textTheme.ppMori400White14,
            ),
            const SizedBox(height: 16),
            _displayOrientationPreview(
              deviceStatus?.screenRotation,
            ),
            const SizedBox(height: 16),
            PrimaryAsyncButton(
              text: 'rotate'.tr(),
              color: AppColor.white,
              enabled: state.isDeviceAlive(blDevice) && deviceStatus != null,
              onTap: () async {
                final response = await injector<CanvasClientServiceV2>()
                    .rotateCanvas(blDevice);
                if (response != null) {
                  final deviceStatus =
                      BluetoothDeviceManager().castingDeviceStatus.value;
                  if (deviceStatus != null) {
                    BluetoothDeviceManager().castingDeviceStatus.value =
                        deviceStatus.copyWith(screenRotation: response);
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _canvasSetting(BuildContext context) {
    final blDevice = selectedDevice!;
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      buildWhen: (previous, current) {
        return previous.statusOf(blDevice)?.deviceSettings?.scaling !=
                current.statusOf(blDevice)?.deviceSettings?.scaling ||
            previous.isDeviceAlive(blDevice) != current.isDeviceAlive(blDevice);
      },
      builder: (context, state) {
        final deviceState = state.statusOf(blDevice);
        final artFramingIndex =
            (deviceState?.deviceSettings?.scaling == ArtFraming.cropToFill)
                ? 1
                : 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'canvas'.tr(),
              style: Theme.of(context).textTheme.ppMori400White14,
            ),
            const SizedBox(height: 30),
            SelectDeviceConfigView(
              selectedIndex: artFramingIndex,
              isEnable: state.isDeviceAlive(blDevice) && deviceState != null,
              items: [
                DeviceConfigItem(
                  title: 'fit'.tr(),
                  icon: Image.asset(
                    'assets/images/fit.png',
                    width: 100,
                    height: 100,
                  ),
                  onSelected: () async {
                    final completer = Completer<void>();
                    injector<CanvasDeviceBloc>().add(
                      CanvasDeviceUpdateArtFramingEvent(
                        blDevice,
                        ArtFraming.fitToScreen,
                        completer.completeError,
                        completer.complete,
                      ),
                    );
                    await completer.future;
                  },
                ),
                DeviceConfigItem(
                  title: 'fill'.tr(),
                  icon: Image.asset(
                    'assets/images/fill.png',
                    width: 100,
                    height: 100,
                  ),
                  onSelected: () async {
                    final completer = Completer<void>();
                    injector<CanvasDeviceBloc>().add(
                      CanvasDeviceUpdateArtFramingEvent(
                        blDevice,
                        ArtFraming.cropToFill,
                        completer.completeError,
                        completer.complete,
                      ),
                    );
                    await completer.future;
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _wifiConfig(BuildContext context) {
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      buildWhen: (previous, current) {
        return previous.isDeviceAlive(selectedDevice!) !=
            current.isDeviceAlive(selectedDevice!);
      },
      builder: (context, state) {
        final isEnabled =
            state.isDeviceAlive(selectedDevice!) && deviceStatus != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TappableForwardRow(
              leftWidget: Row(
                children: [
                  Text(
                    'configure_wifi'.tr(),
                    style:
                        Theme.of(context).textTheme.ppMori400White14.copyWith(
                              color: isEnabled
                                  ? AppColor.white
                                  : AppColor.disabledColor,
                            ),
                  ),
                ],
              ),
              forwardIcon: SvgPicture.asset(
                'assets/images/iconForward.svg',
                colorFilter: ColorFilter.mode(
                  isEnabled ? AppColor.white : AppColor.disabledColor,
                  BlendMode.srcIn,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              onTap: isEnabled
                  ? () {
                      injector<NavigationService>().navigateTo(
                        AppRouter.scanWifiNetworkPage,
                        arguments: ScanWifiNetworkPagePayload(
                          selectedDevice!,
                          onWifiSelected,
                        ),
                      );
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }

  FutureOr<void> onWifiSelected(WifiPoint accessPoint) {
    final blDevice = selectedDevice!;
    log.info('onWifiSelected: $accessPoint');
    final payload = SendWifiCredentialsPagePayload(
      wifiAccessPoint: accessPoint,
      device: blDevice,
      onSubmitted: (_, __) {
        injector<NavigationService>()
            .popUntil(AppRouter.bluetoothConnectedDeviceConfig);
      },
    );
    injector<NavigationService>()
        .navigateTo(AppRouter.sendWifiCredentialPage, arguments: payload);
  }

  Widget _deviceInfoItem(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.ppMori400Grey14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _deviceInfo(BuildContext context) {
    final device = selectedDevice!;
    final version = deviceStatus?.installedVersion;
    final installedVersion = deviceStatus?.installedVersion ?? version;
    final branchName = device.isReleaseBranch ? '' : ' (${device.branchName})';
    final theme = Theme.of(context);
    final deviceId = device.deviceId;
    final connectedWifi = deviceStatus?.connectedWifi;

    final divider = addDivider(
      height: 16,
      color: AppColor.primaryBlack,
    );

    return BlocConsumer<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      listener: (context, state) {},
      buildWhen: (previous, current) {
        return previous.isDeviceAlive(device) != current.isDeviceAlive(device);
      },
      builder: (context, state) {
        final isBLEDeviceConnected = state.isDeviceAlive(device);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Device Information',
                    style: theme.textTheme.ppMori400White14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Connection Status
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColor.auGreyBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // connection status
                  _deviceInfoItem(
                    context,
                    title: 'Connection Status:',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isBLEDeviceConnected
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isBLEDeviceConnected
                                ? 'Connected'
                                : 'Device not connected',
                            style: theme.textTheme.ppMori400White14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  divider,

                  // Device Id

                  _deviceInfoItem(
                    context,
                    title: 'Device Id:',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            deviceId,
                            style: theme.textTheme.ppMori400White14.copyWith(
                              color: isBLEDeviceConnected
                                  ? AppColor.white
                                  : AppColor.disabledColor,
                            ),
                          ),
                        ),
                        _copyButton(
                          context,
                          deviceId,
                        ),
                      ],
                    ),
                  ),
                  divider,
                  // software version
                  _deviceInfoItem(
                    context,
                    title: 'Software Version',
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.ppMori400White14.copyWith(
                          color: isBLEDeviceConnected
                              ? AppColor.white
                              : AppColor.disabledColor,
                        ),
                        children: [
                          TextSpan(
                            text: (installedVersion ?? '-') + branchName,
                          ),
                        ],
                      ),
                    ),
                  ),
                  divider,

                  // WiFi Network
                  // Check if the device is connected to WiFi
                  // If not connected, show "Not connected" message
                  // If connected, show the connected WiFi name
                  if (deviceStatus != null) ...[
                    _deviceInfoItem(
                      context,
                      title: 'Device Wifi Network',
                      child: Text(
                        connectedWifi ?? '-',
                        style: theme.textTheme.ppMori400White14.copyWith(
                          color: isBLEDeviceConnected
                              ? AppColor.white
                              : AppColor.disabledColor,
                        ),
                      ),
                    ),
                    divider,
                  ],
                  ...[
                    _deviceInfoItem(
                      context,
                      title: 'Screen Resolution',
                      child: Builder(
                        builder: (context) {
                          final resolution =
                              _latestMetrics?.screen?.sizeOnOrientation(
                            deviceStatus?.screenRotation ??
                                ScreenOrientation.landscape,
                          );
                          return Text(
                            resolution == null
                                ? '--'
                                : '${resolution.width.toInt()} x ${resolution.height.toInt()}',
                            style: theme.textTheme.ppMori400White14.copyWith(
                              color: isBLEDeviceConnected
                                  ? AppColor.white
                                  : AppColor.disabledColor,
                            ),
                          );
                        },
                      ),
                    ),
                    divider,
                  ],
                  // refresh rate
                  ...[
                    _deviceInfoItem(
                      context,
                      title: 'Refresh Rate',
                      child: Text(
                        _latestMetrics?.screen?.refreshRate == null
                            ? '--'
                            : '${_latestMetrics!.screen!.refreshRate} Hz',
                        style: theme.textTheme.ppMori400White14.copyWith(
                          color: isBLEDeviceConnected
                              ? AppColor.white
                              : AppColor.disabledColor,
                        ),
                      ),
                    ),
                    divider,
                  ],
                  if (isBLEDeviceConnected) ...[
                    const SizedBox(height: 16),
                    PrimaryAsyncButton(
                      text: _isShowingQRCode
                          ? 'Hide QR Code'
                          : 'Show Pairing QR Code',
                      color: AppColor.white,
                      onTap: () async {
                        final device = selectedDevice!;
                        await injector<CanvasClientServiceV2>()
                            .showPairingQRCode(device, !_isShowingQRCode);
                        setState(() {
                          _isShowingQRCode = !_isShowingQRCode;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _copyButton(BuildContext context, String deviceId) {
    return GestureDetector(
      onTap: () {
        showSimpleNotificationToast(
          key: const Key('deviceID'),
          content: 'Device Id copied to clipboard',
        );
        unawaited(
          Clipboard.setData(ClipboardData(text: deviceId)),
        );
      },
      child: SvgPicture.asset(
        'assets/images/copy.svg',
        height: 16,
        width: 16,
        colorFilter: const ColorFilter.mode(
          AppColor.white,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  // // Enable metrics streaming from the device
  Future<void> _enableMetricsStreaming() async {
    try {
      _metricsStreamSubscription = RealtimeMetricsManager()
          .startRealtimeMetrics()
          .listen(_updateMetricsFromStream);
    } catch (e) {
      log.warning('Failed to enable metrics streaming: $e');
    }
  }

  // // Disable metrics streaming from the device
  Future<void> _stopMetricsStreaming() async {
    try {
      await _metricsStreamSubscription?.cancel();
      RealtimeMetricsManager().stopRealtimeMetrics();
    } catch (e) {
      log.warning('Failed to disable metrics streaming: $e');
    }
  }

  void _updateMetricsFromStream(DeviceRealtimeMetrics metrics) {
    if (!mounted) return;

    setState(() {
      _latestMetrics = metrics;
      // Add new performance data points
      final timestamp = metrics.timestamp.toDouble();
      if (metrics.cpu?.cpuUsage != null) {
        _cpuPoints.add(FlSpot(timestamp, metrics.cpu!.cpuUsage!));
      }
      if (metrics.memory?.memoryUsage != null) {
        _memoryPoints.add(FlSpot(timestamp, metrics.memory!.memoryUsage!));
      }
      if (metrics.gpu?.gpuUsage != null) {
        _gpuPoints.add(FlSpot(timestamp, metrics.gpu!.gpuUsage!));
      }
      if (metrics.cpu?.currentTemperature != null) {
        _cpuTempPoints.add(FlSpot(timestamp, metrics.cpu!.currentTemperature!));
      }
      if (metrics.gpu?.currentTemperature != null) {
        _gpuTempPoints.add(FlSpot(timestamp, metrics.gpu!.currentTemperature!));
      }

      if (metrics.screen?.fps != null) {
        _fpsPoints.add(FlSpot(timestamp, metrics.screen!.fps!));
      }

      // Remove old points if we exceed the limit
      while (_cpuPoints.length > _maxDataPoints) {
        _cpuPoints.removeAt(0);
        _memoryPoints.removeAt(0);
        _gpuPoints.removeAt(0);
        _cpuTempPoints.removeAt(0);
        _gpuTempPoints.removeAt(0);
      }

      // sort points by timestamp
      _cpuPoints.sort((a, b) => a.x.compareTo(b.x));
      _memoryPoints.sort((a, b) => a.x.compareTo(b.x));
      _gpuPoints.sort((a, b) => a.x.compareTo(b.x));
      _cpuTempPoints.sort((a, b) => a.x.compareTo(b.x));
      _gpuTempPoints.sort((a, b) => a.x.compareTo(b.x));
      _fpsPoints.sort((a, b) => a.x.compareTo(b.x));

      final maxPerformanceValue = [
        ..._cpuPoints.map((e) => e.y),
        ..._memoryPoints.map((e) => e.y),
        ..._gpuPoints.map((e) => e.y),
      ].reduce((a, b) => a > b ? a : b);
      final minPerformanceValue = [
        ..._cpuPoints.map((e) => e.y),
        ..._memoryPoints.map((e) => e.y),
        ..._gpuPoints.map((e) => e.y),
      ].reduce((a, b) => a < b ? a : b);

      // _maxTemperatureValue = max of all temperature points
      final maxTemperatureValue = [
        ..._cpuTempPoints.map((e) => e.y),
        ..._gpuTempPoints.map((e) => e.y),
      ].reduce((a, b) => a > b ? a : b);

      final minTemperatureValue = [
        ..._cpuTempPoints.map((e) => e.y),
        ..._gpuTempPoints.map((e) => e.y),
      ].reduce((a, b) => a < b ? a : b);

      setState(() {
        _maxPerformanceValue = maxPerformanceValue;
        _minPerformanceValue = minPerformanceValue;
        _maxTemperatureValue = maxTemperatureValue;
        _minTemperatureValue = minTemperatureValue;
      });
    });
  }

  Widget _performanceMonitoring(BuildContext context) {
    final theme = Theme.of(context);

    // Define colors for each metric
    const cpuColor = Colors.blue;
    const memoryColor = Colors.green;
    const gpuColor = Colors.red;

    // Get the latest values from the points arrays
    final cpuValue = _cpuPoints.isNotEmpty ? _cpuPoints.last.y : null;
    final memoryValue = _memoryPoints.isNotEmpty ? _memoryPoints.last.y : null;
    final gpuValue = _gpuPoints.isNotEmpty ? _gpuPoints.last.y : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Monitoring',
          style: theme.textTheme.ppMori400White14,
        ),
        const SizedBox(height: 16),

        // Current values display
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColor.auGreyBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricDisplay('CPU', cpuValue, '%', cpuColor),
              _metricDisplay('Memory', memoryValue, '%', memoryColor),
              _metricDisplay('GPU', gpuValue, '%', gpuColor),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Performance chart
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColor.auGreyBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              minY: _cpuPoints.isEmpty ? 0 : max(_minPerformanceValue - 10, 0),
              maxY: _cpuPoints.isEmpty
                  ? 100
                  : min(_maxPerformanceValue + 10, 100),
              // Percentage values 0-100
              minX: _cpuPoints.isEmpty ? 0 : _cpuPoints.first.x,
              maxX: _cpuPoints.isEmpty ? 100 : _cpuPoints.last.x,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: AppColor.feralFileMediumGrey,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _createLineData(_cpuPoints, cpuColor, 'CPU'),
                _createLineData(_memoryPoints, memoryColor, 'Memory'),
                _createLineData(_gpuPoints, gpuColor, 'GPU'),
              ],
              titlesData: FlTitlesData(
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 25,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: theme.textTheme.ppMori400White12,
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(
                    reservedSize: 30,
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchCallback:
                    (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  if (event is FlTapDownEvent) {
                    HapticFeedback.lightImpact();
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(12),
                  tooltipMargin: 8,
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    // Sort spots by barIndex to ensure consistent order
                    final sortedSpots = List<LineBarSpot>.from(touchedBarSpots)
                      ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

                    // Get timestamp from the first spot (all spots have the same timestamp)
                    final timestamp = sortedSpots.isNotEmpty
                        ? '\nTime: ${_formatTimestamp(sortedSpots.first.x)}'
                        : '';

                    return sortedSpots.asMap().entries.map((entry) {
                      final index = entry.key;
                      final barSpot = entry.value;

                      final metric = barSpot.barIndex == 0
                          ? 'CPU'
                          : barSpot.barIndex == 1
                              ? 'Memory'
                              : 'GPU';
                      final color = barSpot.barIndex == 0
                          ? cpuColor
                          : barSpot.barIndex == 1
                              ? memoryColor
                              : gpuColor;

                      return LineTooltipItem(
                        '$metric: ${barSpot.y.toStringAsFixed(1)}%',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: index == sortedSpots.length - 1
                            ? [
                                TextSpan(
                                  text: timestamp,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 10,
                                  ),
                                ),
                              ]
                            : null,
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _temperatureMonitoring(BuildContext context) {
    final theme = Theme.of(context);

    // Define colors for each metric
    const cpuTempColor = Colors.blue;
    const gpuTempColor = Colors.red;

    // Get the latest values from the points arrays
    final cpuTempValue =
        _cpuTempPoints.isNotEmpty ? _cpuTempPoints.last.y : null;
    final gpuTempValue =
        _gpuTempPoints.isNotEmpty ? _gpuTempPoints.last.y : null;

    // Convert to Fahrenheit if needed
    final cpuTempDisplayValue = cpuTempValue;
    final gpuTempDisplayValue = gpuTempValue;

    // Temperature unit
    const tempUnit = '°C';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temperature Monitoring',
          style: theme.textTheme.ppMori400White14,
        ),
        const SizedBox(height: 16),

        // Current values display
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColor.auGreyBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricDisplay(
                'CPU Temp',
                cpuTempDisplayValue,
                tempUnit,
                cpuTempColor,
              ),
              _metricDisplay(
                'GPU Temp',
                gpuTempDisplayValue,
                tempUnit,
                gpuTempColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Temperature chart
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppColor.auGreyBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16),
          child: LineChart(
            LineChartData(
              minY: _cpuTempPoints.isEmpty ? 0 : _minTemperatureValue - 10,
              // 30°C = 86°F
              maxY: _cpuTempPoints.isEmpty ? 100 : _maxTemperatureValue + 10,
              // 100°C = 212°F
              minX: _cpuTempPoints.isEmpty ? 0 : _cpuTempPoints.first.x,
              maxX: _cpuTempPoints.isEmpty ? 100 : _cpuTempPoints.last.x,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: AppColor.feralFileMediumGrey,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _createLineData(
                  _cpuTempPoints,
                  cpuTempColor,
                  'CPU Temp',
                ),
                _createLineData(
                  _gpuTempPoints,
                  gpuTempColor,
                  'GPU Temp',
                ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: 20, // ~20°C = 36°F interval
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}$tempUnit',
                        style: theme.textTheme.ppMori400White12,
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
              ),
              lineTouchData: LineTouchData(
                touchCallback:
                    (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  if (event is FlTapDownEvent) {
                    HapticFeedback.lightImpact();
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(12),
                  tooltipMargin: 8,
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    // Sort spots by barIndex to ensure consistent order
                    final sortedSpots = List<LineBarSpot>.from(touchedBarSpots)
                      ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

                    // Get timestamp from the first spot (all spots have the same timestamp)
                    final timestamp = sortedSpots.isNotEmpty
                        ? '\nTime: ${_formatTimestamp(sortedSpots.first.x)}'
                        : '';

                    return sortedSpots.asMap().entries.map((entry) {
                      final index = entry.key;
                      final barSpot = entry.value;

                      final metric =
                          barSpot.barIndex == 0 ? 'CPU Temp' : 'GPU Temp';
                      final color =
                          barSpot.barIndex == 0 ? cpuTempColor : gpuTempColor;
                      final value = barSpot.y;

                      return LineTooltipItem(
                        '$metric: ${value.toStringAsFixed(1)}$tempUnit',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: index == sortedSpots.length - 1
                            ? [
                                TextSpan(
                                  text: timestamp,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 10,
                                  ),
                                ),
                              ]
                            : null,
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricDisplay(String label, double? value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.ppMori400Grey14,
        ),
        const SizedBox(height: 4),
        Text(
          '${value?.toStringAsFixed(1) ?? '--'} $unit',
          style: Theme.of(context).textTheme.ppMori400White14.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  LineChartBarData _createLineData(
    List<FlSpot> points,
    Color color,
    String label,
  ) {
    // If no data points, return empty line with dotted style
    if (points.isEmpty) {
      return LineChartBarData(
        spots: [
          FlSpot(0, 0),
          FlSpot(100, 0),
        ],
        dotData: const FlDotData(show: false),
        color: color.withOpacity(0.3),
        barWidth: 1,
        isCurved: false,
        dashArray: [5, 5],
        // Create dotted line effect
        belowBarData: BarAreaData(show: false),
      );
    }

    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(
        show: false,
      ),
      color: color,
      barWidth: 3,
      isCurved: true,
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(40),
      ),
    );
  }

  // Helper method to format timestamp for tooltip display
  String _formatTimestamp(double timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  void resetMetrics() {
    setState(() {
      _cpuPoints.clear();
      _memoryPoints.clear();
      _gpuPoints.clear();
      _cpuTempPoints.clear();
      _gpuTempPoints.clear();
      _fpsPoints.clear();
      _latestMetrics = null;
    });
  }

  Widget _buildDeviceSwitcher(BuildContext context) {
    final pairedDevices = BluetoothDeviceManager.pairedDevices;

    // If there are less than 2 devices, don't show the switcher
    if (pairedDevices.length < 2) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<FFBluetoothDevice>(
      icon: const Icon(
        Icons.devices,
        color: AppColor.white,
        size: 24,
      ),
      tooltip: 'Switch Device',
      offset: const Offset(0, 40),
      onSelected: (FFBluetoothDevice device) async {
        await BluetoothDeviceManager().switchDevice(device);
        setState(() {
          selectedDevice = device;
        });
        // Reset metrics when switching devices
        resetMetrics();
      },
      itemBuilder: (BuildContext context) {
        return pairedDevices.map((FFBluetoothDevice device) {
          final isSelected = device.deviceId == selectedDevice?.deviceId;
          return PopupMenuItem<FFBluetoothDevice>(
            value: device,
            child: Row(
              children: [
                Icon(
                  Icons.tv,
                  color: isSelected
                      ? AppColor.white
                      : AppColor.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    device.name,
                    style: TextStyle(
                      color: isSelected
                          ? AppColor.white
                          : AppColor.white.withValues(alpha: 0.9),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    color: AppColor.white,
                    size: 16,
                  ),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }

  void _showOption(BuildContext context, CanvasDeviceState state) {
    final isDeviceAlive = selectedDevice.isAlive;

    final options = [
      if (isDeviceAlive)
        OptionItem(
          title: 'Power Off',
          icon: const Icon(
            Icons.power_settings_new,
            size: 24,
          ),
          onTap: () {
            _onPowerOffSelected();
          },
        ),
      // reboot
      if (isDeviceAlive)
        OptionItem(
          title: 'Restart',
          icon: const Icon(
            Icons.restart_alt,
            size: 24,
          ),
          onTap: () {
            _onRebootSelected();
          },
        ),
      OptionItem(
        title: 'Send Log',
        icon: Icon(AuIcon.help),
        onTap: () async {
          await _onSendLogSelected();
        },
      ),
      if (kDebugMode)
        OptionItem(
          title: 'Factory Reset',
          icon: Icon(Icons.restart_alt),
          onTap: () {
            _onFactoryResetSelected();
          },
        ),
      OptionItem.emptyOptionItem,
    ];
    unawaited(UIHelper.showDrawerAction(context,
        options: options, title: selectedDevice?.name));
  }

  Future<void> _onFactoryResetSelected() async {
    final error = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Factory Reset',
            style: Theme.of(context).textTheme.ppMori700White16,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to reset the device to factory settings? This will erase all data and cannot be undone.',
            style: Theme.of(context).textTheme.ppMori400White14,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'cancel'.tr(),
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    injector<NavigationService>().goBack(result: null);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Reset',
                  textColor: AppColor.white,
                  borderColor: AppColor.white,
                  color: Colors.transparent,
                  onTap: () async {
                    try {
                      final device = selectedDevice!;
                      await injector<FFBluetoothService>().factoryReset(device);
                      unawaited(device.disconnect());
                      await BluetoothDeviceManager()
                          .removeDevice(device.deviceId);
                      injector<NavigationService>().goBack(result: true);
                    } catch (e) {
                      injector<NavigationService>().goBack(result: e);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (error is bool) {
      if (error) {
        injector<NavigationService>().popUntilHome();
        await UIHelper.showInfoDialog(context, 'Restoring Factory Defaults',
            'The device is now restoring to factory settings. It may take some time to complete. Please keep the device powered on and wait until the reset is finished.');
      }
    } else if (error != null) {
      await UIHelper.showInfoDialog(context, 'Factory Reset Failed',
          'Something went wrong while trying to restore the device to factory settings. ${error.toString()}');
    }
  }

  void _onPowerOffSelected() {
    UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Power Off',
            style: Theme.of(context).textTheme.ppMori700White16,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to power off the device?',
            style: Theme.of(context).textTheme.ppMori400White14,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'cancel'.tr(),
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    injector<NavigationService>().goBack();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'OK',
                  textColor: AppColor.white,
                  borderColor: AppColor.white,
                  color: Colors.transparent,
                  onTap: () async {
                    final device = selectedDevice!;
                    await injector<CanvasClientServiceV2>()
                        .safeShutdown(device);
                    injector<NavigationService>().goBack();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onRebootSelected() {
    UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restart',
            style: Theme.of(context).textTheme.ppMori700White16,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to restart the device?',
            style: Theme.of(context).textTheme.ppMori400White14,
          ),
          const SizedBox(height: 36),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'cancel'.tr(),
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    injector<NavigationService>().goBack();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'OK',
                  textColor: AppColor.white,
                  borderColor: AppColor.white,
                  color: Colors.transparent,
                  onTap: () async {
                    final device = selectedDevice!;
                    await injector<CanvasClientServiceV2>().safeRestart(device);
                    injector<NavigationService>().goBack();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onSendLogSelected() async {
    final theme = Theme.of(context);
    try {
      final device = selectedDevice;
      await injector<FFBluetoothService>().sendLog(device, null);
      UIHelper.showDialog(
          context,
          'Log sent',
          Text(
            'Log sent to support',
            style: theme.textTheme.ppMori400White14,
          ));
    } catch (e) {
      log.info('Error sending log: $e');
      UIHelper.showDialog(
          context,
          'Failed to send log',
          Text(
            'Failed to send log to support. Error: $e',
            style: theme.textTheme.ppMori400White14,
          ));
    }
  }
}
