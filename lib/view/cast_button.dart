import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/widgets/buttons/play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentry/sentry.dart';

class FFCastButton extends StatefulWidget {
  const FFCastButton({
    this.type = '',
    super.key,
    this.onDeviceSelected,
    this.text,
    this.shouldCheckSubscription = true,
    this.onTap,
  });

  final FutureOr<void> Function(BaseDevice device)? onDeviceSelected;
  final String? text;
  final String? type;
  final bool shouldCheckSubscription;
  final VoidCallback? onTap;

  @override
  State<FFCastButton> createState() => FFCastButtonState();
}

class FFCastButtonState extends State<FFCastButton>
    with AfterLayoutMixin<FFCastButton> {
  late CanvasDeviceBloc _canvasDeviceBloc;

  @override
  void initState() {
    super.initState();
    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
    injector<SubscriptionBloc>().add(GetSubscriptionEvent());
  }

  @override
  void afterFirstLayout(BuildContext context) {}

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: _canvasDeviceBloc,
      builder: (context, state) {
        final hasDevice = state.activeDevices.isNotEmpty;
        if (!hasDevice) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, subscriptionState) {
            final isSubscribed = subscriptionState.isSubscribed;
            return PlayButton(
              onTap: () async {
                try {
                  widget.onTap?.call();
                  await onTap(context, isSubscribed);
                } catch (e) {
                  log.info('Error while casting: $e');
                  unawaited(
                    Sentry.captureException(
                      '[FFCastButton] Error while casting: $e',
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> onTap(BuildContext context, bool isSubscribed) async {
    final device = BluetoothDeviceManager().castingBluetoothDevice;
    if (device != null) {
      await widget.onDeviceSelected?.call(device);
    }
  }
}

class ProcessingIndicator extends StatefulWidget {
  const ProcessingIndicator({super.key});

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator> {
  int _colorIndex = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _colorIndex = (_colorIndex + 1) % 2;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return dot with color flicker
    final colors = [
      AppColor.primaryBlack,
      AppColor.feralFileLightBlue,
    ];
    final color = colors[_colorIndex];
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
