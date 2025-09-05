import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/view/stream_common_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StreamDeviceView extends StatefulWidget {
  const StreamDeviceView({
    super.key,
    this.onDeviceSelected,
    this.displayKey,
  });

  final FutureOr<void> Function(BaseDevice device)? onDeviceSelected;
  final String? displayKey;

  @override
  State<StreamDeviceView> createState() => _StreamDeviceViewState();
}

class _StreamDeviceViewState extends State<StreamDeviceView> {
  late final CanvasDeviceBloc _canvasDeviceBloc;

  @override
  void initState() {
    super.initState();
    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: _canvasDeviceBloc,
      builder: (context, state) {
        final devices = state.devices;
        final connectedDevice = widget.displayKey == null
            ? null
            : state.lastSelectedActiveDeviceForKey(widget.displayKey!);

        final isDeviceListEmpty = devices.isEmpty;

        return Padding(
          padding: ResponsiveLayout.pageHorizontalEdgeInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: (connectedDevice != null)
                        ? RichText(
                            textScaler: MediaQuery.textScalerOf(context),
                            text: TextSpan(
                              style: theme.textTheme.ppMori700White24,
                              children: <TextSpan>[
                                TextSpan(
                                  text: 'display'.tr(),
                                ),
                                TextSpan(
                                  text: ' ${connectedDevice.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Text(
                            'display_art_on_your_tv'.tr(),
                            style: theme.textTheme.ppMori700White24,
                          ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Padding(
                      padding: const EdgeInsets.all(5),
                      child: SvgPicture.asset(
                        'assets/images/circle_close.svg',
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isDeviceListEmpty) ...[
                const SizedBox(height: 40),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: devices.length,
                  itemBuilder: (BuildContext context, int index) {
                    final device = devices[index];
                    if (device is FFBluetoothDevice) {
                      return _bluetoothDeviceItemBuilder(
                        context: context,
                        device: device,
                        isControlling:
                            device.deviceId == connectedDevice?.deviceId,
                      );
                    } else {
                      return Text(
                        'device_not_supported'.tr(),
                        style: theme.textTheme.ppMori400White14,
                      );
                    }
                  },
                ),
                if (connectedDevice != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: AppColor.white,
                      ),
                    ),
                    width: MediaQuery.of(context).size.width,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        splashFactory: InkSparkle.splashFactory,
                        borderRadius: BorderRadius.circular(50),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: Text(
                              'disconnect'.tr(),
                              style: theme.textTheme.ppMori400White14,
                            ),
                          ),
                        ),
                        onTap: () async {
                          await onDisconnect();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ] else ...[
                const SizedBox(height: 15),
              ],
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _bluetoothDeviceItemBuilder({
    required BuildContext context,
    required FFBluetoothDevice device,
    bool? isControlling,
  }) {
    return Column(
      children: [
        Builder(
          builder: (context) => StreamDrawerItem(
            item: OptionItem(
              title: '${device.name}(${device.deviceId})',
              onTap: () {
                widget.onDeviceSelected?.call(device);
                Navigator.pop(context);
              },
              icon: SvgPicture.asset(
                'assets/images/bluetooth.svg',
                width: 20,
                height: 20,
              ),
            ),
            backgroundColor: isControlling == null
                ? AppColor.white
                : isControlling
                    ? AppColor.feralFileLightBlue
                    : AppColor.disabledColor,
            isControlling: isControlling ?? false,
            onRotateClicked: () => onRotate(context),
          ),
        ),
        const SizedBox(
          height: 15,
        ),
      ],
    );
  }

  void onRotate(BuildContext context) {
    final lastSelectedCanvasDevice = _canvasDeviceBloc.state
        .lastSelectedActiveDeviceForKey(widget.displayKey!);
    if (lastSelectedCanvasDevice != null) {
      _canvasDeviceBloc.add(CanvasDeviceRotateEvent(lastSelectedCanvasDevice));
    }
  }

  Future<void> onDisconnect() async {
    final allDevices = _canvasDeviceBloc.state.devices.toList();
    // _canvasDeviceBloc.add(CanvasDeviceDisconnectedEvent(allDevices));
  }
}
