import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/SleepModeIndicator.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:flutter/material.dart';

class SleepModeIndicator extends StatelessWidget {
  const SleepModeIndicator({required this.isSleeping, super.key});
  final bool isSleeping;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final connectedDevice = BluetoothDeviceManager().castingBluetoothDevice;
        if (connectedDevice == null) {
          return;
        }

        injector<CanvasClientServiceV2>().setSleepMode(
          connectedDevice,
          !isSleeping,
        );
      },
      child: Container(
        width: SleepModeIndicatorTokens.size.toDouble(),
        height: SleepModeIndicatorTokens.size.toDouble(),
        padding: EdgeInsets.all(SleepModeIndicatorTokens.padding.toDouble()),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isSleeping
                ? SleepModeIndicatorTokens.bgInactiveColor
                : SleepModeIndicatorTokens.bgActiveColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
