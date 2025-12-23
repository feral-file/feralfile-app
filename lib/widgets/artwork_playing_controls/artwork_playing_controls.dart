import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/canvas_cast_request_reply.dart';
import 'package:autonomy_flutter/model/device/ff_bluetooth_device.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/widgets/buttons/core_button.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

class ArtworkPlayingControls extends StatelessWidget {
  const ArtworkPlayingControls({required this.playingDevice, super.key});
  final FFBluetoothDevice playingDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 243 / 393,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: PrimitivesTokens.colorsDarkGrey,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _rotateButton(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _framingButton(ArtFraming.fitToScreen, true)),
              const SizedBox(width: 12),
              Expanded(child: _framingButton(ArtFraming.cropToFill, false)),
            ],
          ),
          // const SizedBox(height: 12),
          // _rotateButton(),
        ],
      ),
    );
  }

  Widget _rotateButton() {
    return CoreButton(
      text: 'Rotate',
      leftIcon: Transform.flip(
        flipY: true,
        child: SvgPicture.asset(
          'assets/images/icon_rotate_white.svg',
          width: 13.71,
          height: 18,
        ),
      ),
      color: PrimitivesTokens.colorsBlack,
      textColor: PrimitivesTokens.colorsWhite,
      isAsync: true,
      onTap: () async {
        final response =
            await injector<CanvasClientServiceV2>().rotateCanvas(playingDevice);
        if (response != null) {
          final deviceStatus =
              BluetoothDeviceManager().castingDeviceStatus.value;
          if (deviceStatus != null) {
            BluetoothDeviceManager().castingDeviceStatus.value =
                deviceStatus.copyWith(screenRotation: response);
          }
        }
      },
    );
  }

  Widget _framingButton(ArtFraming type, bool isSelected) {
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: injector<CanvasDeviceBloc>(),
      builder: (context, state) {
        final deviceStatus = state.statusOf(playingDevice);
        final isSelected = deviceStatus?.deviceSettings?.scaling == type;
        return CoreButton(
          text: type.name.capitalize(),
          leftIcon: Container(
            height: 11,
            width: 11,
            decoration: const BoxDecoration(
              color: PrimitivesTokens.colorsDarkGrey,
              shape: BoxShape.circle,
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      height: 6,
                      width: 6,
                      decoration: const BoxDecoration(
                        color: PrimitivesTokens.colorsWhite,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          color: PrimitivesTokens.colorsBlack,
          textColor: PrimitivesTokens.colorsWhite,
          isAsync: true,
          onTap: () async {
            await injector<CanvasClientServiceV2>()
                .updateArtFraming(playingDevice, type);
          },
        );
      },
    );
  }
}
