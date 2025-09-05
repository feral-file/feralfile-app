import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/text_style_ext.dart';
import 'package:flutter/material.dart';

class DeviceSubNav extends StatefulWidget {
  const DeviceSubNav({super.key});

  @override
  State<DeviceSubNav> createState() => _DeviceSubNavState();
}

class _DeviceSubNavState extends State<DeviceSubNav> {
  FFBluetoothDevice? selectedDevice;

  @override
  void initState() {
    super.initState();
    selectedDevice = BluetoothDeviceManager().castingBluetoothDevice;

    // Listen to device status changes to sync with singleton
    BluetoothDeviceManager()
        .castingDeviceStatus
        .addListener(_onDeviceStatusChanged);
  }

  @override
  void dispose() {
    BluetoothDeviceManager()
        .castingDeviceStatus
        .removeListener(_onDeviceStatusChanged);
    super.dispose();
  }

  void _onDeviceStatusChanged() {
    final currentDevice = BluetoothDeviceManager().castingBluetoothDevice;
    if (mounted && selectedDevice?.deviceId != currentDevice?.deviceId) {
      setState(() {
        selectedDevice = currentDevice;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pairedDevices = BluetoothDeviceManager.pairedDevices;

    if (pairedDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: pairedDevices.map((device) {
            final index = pairedDevices.indexOf(device);
            return Row(
              children: [
                if (index > 0)
                  SizedBox(
                    width: NowPlayingBarTokens.bottomDeviceNavGap.toDouble(),
                  ),
                GestureDetector(
                  child: Text(
                    pairedDevices[index].name,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeightUtil.fromString(
                        PrimitivesTokens.fontWeightsBold,
                      ),
                      color: selectedDevice?.deviceId ==
                              pairedDevices[index].deviceId
                          ? NowPlayingBarTokens.bottomDeviceNavActiveColor
                          : NowPlayingBarTokens.bottomDeviceNavInactiveColor,
                    ),
                  ),
                  onTap: () async {
                    if (selectedDevice?.deviceId ==
                        pairedDevices[index].deviceId) {
                      return;
                    }

                    await BluetoothDeviceManager().switchDevice(device);
                  },
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
