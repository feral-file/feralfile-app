import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class NowDisplayingQuickSettingView extends StatefulWidget {
  const NowDisplayingQuickSettingView({super.key});

  @override
  State<NowDisplayingQuickSettingView> createState() =>
      _NowDisplayingQuickSettingViewState();
}

class _NowDisplayingQuickSettingViewState
    extends State<NowDisplayingQuickSettingView> {
  late ArtFraming selectedFitment;
  late FFBluetoothDevice? connectedDevice;

  @override
  void initState() {
    super.initState();
    initDisplaySettings();

    connectedDevice = BluetoothDeviceManager().castingBluetoothDevice;
    BluetoothDeviceManager().castingDeviceStatus.addListener(
          deviceStatusListener,
        );
  }

  @override
  Future<void> dispose() async {
    BluetoothDeviceManager().castingDeviceStatus.removeListener(
          deviceStatusListener,
        );
    super.dispose();
  }

  void deviceStatusListener() {
    final deviceStatus =
        injector<CanvasDeviceBloc>().state.statusOf(connectedDevice!);
    if (deviceStatus != null &&
        deviceStatus.deviceSettings?.scaling != null &&
        deviceStatus.deviceSettings!.scaling != selectedFitment) {
      if (!mounted) return;
      setState(() {
        selectedFitment = deviceStatus.deviceSettings!.scaling!;
      });
    }
  }

  void initDisplaySettings() {
    final castingDevice = BluetoothDeviceManager().castingBluetoothDevice;
    final deviceStatus =
        injector<CanvasDeviceBloc>().state.statusOf(castingDevice!);
    selectedFitment =
        deviceStatus?.deviceSettings?.scaling ?? ArtFraming.fitToScreen;
  }

  Future<void> _updateFitment(ArtFraming fitment) async {
    if (fitment == selectedFitment) {
      return;
    }

    if (connectedDevice == null) {
      log.warning(
        'NowDisplaySetting: fitmentOption: connectedDevice is null',
      );
      return;
    }

    try {
      unawaited(
        injector<CanvasClientServiceV2>().updateArtFraming(
          connectedDevice!,
          fitment,
        ),
      );
      setState(() {
        selectedFitment = fitment;
      });
    } catch (e) {
      log.warning(
        'NowDisplaySetting: updateDisplaySettings error: $e',
      );
    }
  }

  OptionItem fitmentOption(ArtFraming fitment) {
    return OptionItem(
      title: fitment == ArtFraming.fitToScreen ? 'fit'.tr() : 'fill'.tr(),
      icon: SvgPicture.asset(
        fitment == selectedFitment
            ? 'assets/images/radio_selected.svg'
            : 'assets/images/radio_unselected.svg',
      ),
      onTap: () async {
        await _updateFitment(fitment);
      },
    );
  }

  List<OptionItem> _settingOptions() {
    return [
      OptionItem(
        title: 'Rotate',
        icon: SvgPicture.asset(
          'assets/images/icon_rotate_white.svg',
        ),
        onTap: () async {
          if (connectedDevice == null) {
            log.warning(
              'NowDisplaySetting: fitmentOption: connectedDevice is null',
            );
            return;
          }

          try {
            await injector<CanvasClientServiceV2>()
                .rotateCanvas(connectedDevice!);
          } catch (e) {
            log.warning(
              'NowDisplaySetting: updateDisplaySettings error: $e',
            );
          }
        },
      ),
      fitmentOption(ArtFraming.fitToScreen),
      fitmentOption(ArtFraming.cropToFill),
      // OptionItem.emptyOptionItem,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (connectedDevice == null) {
      return const SizedBox.shrink();
    }
    final itemCount = _settingOptions().length;
    return BlocConsumer<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      listener: (context, state) {
        final selectedDevice = BluetoothDeviceManager().castingBluetoothDevice!;

        if (state.statusOf(selectedDevice) != null &&
            state.statusOf(selectedDevice)!.deviceSettings?.scaling != null &&
            state.statusOf(selectedDevice)!.deviceSettings?.scaling !=
                selectedFitment) {
          setState(() {
            selectedFitment =
                state.statusOf(selectedDevice)!.deviceSettings!.scaling!;
          });
        }
      },
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemBuilder: (BuildContext context, int index) {
                final option = _settingOptions()[index];
                if (option.builder != null) {
                  return option.builder!.call(context, option);
                }
                return DrawerItem(
                  item: option,
                  color: AppColor.white,
                );
              },
              itemCount: itemCount,
              separatorBuilder: (context, index) => (index == itemCount - 1)
                  ? const SizedBox()
                  : const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColor.white,
                    ),
            ),
          ],
        );
      },
    );
  }
}
