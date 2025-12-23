import 'dart:async';
import 'dart:math' as math;

import 'package:after_layout/after_layout.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/model/device/base_device.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/subscription/subscription_state.dart';
import 'package:autonomy_flutter/screen/detail/preview/canvas_device_bloc.dart';
import 'package:autonomy_flutter/service/configuration_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:autonomy_flutter/widgets/buttons/play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sentry/sentry.dart';

class FFCastButton extends StatefulWidget {
  const FFCastButton({
    this.type = '',
    super.key,
    this.onDeviceSelected,
    this.text,
    this.shouldCheckSubscription = true,
    this.onTap,
    this.onTooltipVisibilityChanged,
  });

  final FutureOr<void> Function(BaseDevice device)? onDeviceSelected;
  final String? text;
  final String? type;
  final bool shouldCheckSubscription;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onTooltipVisibilityChanged;

  @override
  State<FFCastButton> createState() => FFCastButtonState();
}

class FFCastButtonState extends State<FFCastButton>
    with AfterLayoutMixin<FFCastButton> {
  late CanvasDeviceBloc _canvasDeviceBloc;
  bool _isProcessing = false;
  bool _showPlayTooltip = false;
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _canvasDeviceBloc = injector.get<CanvasDeviceBloc>();
    injector<SubscriptionBloc>().add(GetSubscriptionEvent());
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _maybeShowPlayTooltip();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _setShowPlayTooltip(bool value) {
    if (_showPlayTooltip == value) {
      return;
    }
    _showPlayTooltip = value;
    if (value) {
      _insertOverlay();
    } else {
      _removeOverlay();
    }
    setState(() {});
    widget.onTooltipVisibilityChanged?.call(value);
  }

  Future<void> _maybeShowPlayTooltip() async {
    final configurationService = injector<ConfigurationService>();
    final hasSeenTooltip = configurationService.hasSeenPlayToFf1Tooltip();
    final hasCastingDevice =
        BluetoothDeviceManager().castingBluetoothDevice != null;

    if (!mounted || hasSeenTooltip || !hasCastingDevice) {
      return;
    }

    _setShowPlayTooltip(true);
  }

  Future<void> _dismissTooltip() async {
    if (!_showPlayTooltip) {
      return;
    }
    _setShowPlayTooltip(false);
    await injector<ConfigurationService>().setHasSeenPlayToFf1Tooltip(true);
  }

  void _insertOverlay() {
    if (_overlayEntry != null || !mounted) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final right = screenWidth - (offset.dx + size.width);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          Positioned(
            right: right,
            top: offset.dy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayButton(
                  isProcessing: _isProcessing,
                  onTap: _handlePlayTap,
                ),
                const SizedBox(height: 18),
                PlayToFF1Tooltip(
                  onDismiss: _dismissTooltip,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _handlePlayTap() async {
    // Dismiss tooltip and perform the same logic as main Play button.
    await _dismissTooltip();
    setState(() {
      _isProcessing = true;
    });
    try {
      widget.onTap?.call();
      await onTap(context, _isSubscribed);
    } catch (e) {
      log.info('Error while casting: $e');
      unawaited(
        Sentry.captureException(
          '[FFCastButton] Error while casting: $e',
        ),
      );
    }
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasDeviceBloc, CanvasDeviceState>(
      bloc: _canvasDeviceBloc,
      builder: (context, state) {
        final hasDevice = state.activeDevices.isNotEmpty;
        if (!hasDevice) {
          return const SizedBox.shrink();
        }
        return BlocBuilder<SubscriptionBloc, SubscriptionState>(
          builder: (context, subscriptionState) {
            _isSubscribed = subscriptionState.isSubscribed;
            return Container(
              key: _buttonKey,
              child: PlayButton(
                isProcessing: _isProcessing,
                onTap: () async {
                  await _handlePlayTap();
                },
              ),
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

class PlayToFF1Tooltip extends StatelessWidget {
  const PlayToFF1Tooltip({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 243 / 393,
            decoration: BoxDecoration(
              color: PrimitivesTokens.colorsDarkGrey,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Tap the Play button to send the playlist to your FF1.',
                    style: Theme.of(context).textTheme.small.copyWith(
                          color: PrimitivesTokens.colorsGrey,
                        ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: SvgPicture.asset(
                      'assets/images/close.svg',
                      width: 12,
                      height: 12,
                      colorFilter: const ColorFilter.mode(
                        PrimitivesTokens.colorsGrey,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: 30,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 12,
                height: 12,
                color: PrimitivesTokens.colorsDarkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
