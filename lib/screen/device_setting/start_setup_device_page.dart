import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/model/error/bluetooth_response_error.dart';
import 'package:autonomy_flutter/model/pair.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/device_setting/bluetooth_connected_device_config.dart';
import 'package:autonomy_flutter/screen/device_setting/enter_wifi_password.dart';
import 'package:autonomy_flutter/screen/device_setting/scan_wifi_network_page.dart';
import 'package:autonomy_flutter/service/bluetooth_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/util/bluetooth_device_ext.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDevicePortalPagePayload {
  BluetoothDevicePortalPagePayload({
    required this.device,
    required this.branchName,
    this.canSkipNetworkSetup = true,
  });

  final BluetoothDevice device;
  final bool canSkipNetworkSetup;
  final String branchName;
}

class BluetoothDevicePortalPage extends StatefulWidget {
  const BluetoothDevicePortalPage({required this.payload, super.key});

  final BluetoothDevicePortalPagePayload payload;

  @override
  State<BluetoothDevicePortalPage> createState() =>
      BluetoothDevicePortalPageState();
}

class BluetoothDevicePortalPageState extends State<BluetoothDevicePortalPage>
    with RouteAware, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getDarkEmptyAppBar(),
      backgroundColor: AppColor.primaryBlack,
      body: SafeArea(
        child: Padding(
          padding: ResponsiveLayout.pageEdgeInsets,
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Row(
                      children: [
                        const Expanded(
                          child: SizedBox(
                            height: 120,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: const Icon(
                            AuIcon.close,
                            color: AppColor.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'FF1',
                        style: Theme.of(context)
                            .textTheme
                            .ppMori700White24
                            .copyWith(
                                letterSpacing: 8.0,
                                height: 0.8,
                                color: AppColor.feralFileLightBlue,
                                fontSize: 98),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 120,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _instruction(context),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(
                      height: 80,
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: PrimaryAsyncButton(
                  onTap: () async {
                    try {
                      final device = widget.payload.device;
                      await injector<FFBluetoothService>()
                          .connectToDevice(device);
                      final canSkipNetworkSetup =
                          widget.payload.canSkipNetworkSetup;
                      if (canSkipNetworkSetup) {
                        Pair<String, bool>? res;
                        try {
                          final topicId =
                              await injector<FFBluetoothService>().keepWifi(
                            device,
                          );
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
                          injector<NavigationService>()
                              .popUntil(AppRouter.bluetoothDevicePortalPage);

                          unawaited(
                              injector<NavigationService>().popAndPushNamed(
                            AppRouter.bluetoothConnectedDeviceConfig,
                            arguments: BluetoothConnectedDeviceConfigPayload(
                              isFromOnboarding: true,
                            ),
                          ));
                        } on FFBluetoothResponseError catch (e) {
                          if (e is DeviceUpdatingError ||
                              e is DeviceVersionCheckFailedError) {
                            injector<NavigationService>().goBack();
                          }
                          final context = injector<NavigationService>().context;
                          await (UIHelper.showInfoDialog(
                              context, e.title, e.message));
                        } on Exception catch (e) {
                          await UIHelper.showInfoDialog(
                            context,
                            'Error',
                            'Failed to skip internet setup: $e',
                          );
                        } finally {
                          if (res == null) {
                            injector<NavigationService>().popUntil(
                              AppRouter.bluetoothDevicePortalPage,
                            );
                            injector<NavigationService>().goBack(result: res);
                          }
                        }
                      } else {
                        unawaited(
                          Navigator.of(context).pushNamed(
                            AppRouter.scanWifiNetworkPage,
                            arguments: ScanWifiNetworkPagePayload(
                              device,
                              onWifiSelected,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      log.info('Error connecting to device: $e');
                    }
                  },
                  color: AppColor.white,
                  text: 'start_device_setup'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  FutureOr<void> onWifiSelected(WifiPoint accessPoint) {
    log.info('onWifiSelected: $accessPoint');
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

  Widget _instruction(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'welcome_to_FF_X1'.tr(),
          style: Theme.of(context).textTheme.ppMori400White16,
        ),
        const SizedBox(height: 16),
        Text(
          'welcome_to_FF_X1_desc'.tr(),
          style: Theme.of(context).textTheme.ppMori400White14,
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 16),
        const Divider(
          color: AppColor.white,
          thickness: 1,
        ),
        const SizedBox(height: 16),
        Text(
          'how_you_can_help'.tr(),
          style: theme.textTheme.ppMori700White16,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8).copyWith(left: 8),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1.',
                    style: theme.textTheme.ppMori400White14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.ppMori400White14,
                        children: [
                          TextSpan(
                            text: '${'experiment_freely'.tr()} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: 'experiment_freely_desc'.tr(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2.',
                    style: theme.textTheme.ppMori400White14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.ppMori400White14,
                        children: [
                          TextSpan(
                            text: '${'share_your_experience'.tr()} ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: '${'join_our'.tr()} ',
                          ),
                          TextSpan(
                            text: 'google_chat_space'.tr(),
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                injector<NavigationService>()
                                    .openGoogleChatSpace();
                              },
                          ),
                          TextSpan(
                            text: ' ${'to_provide_feedback'.tr()}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
