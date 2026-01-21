import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/SleepModeIndicator.dart';
import 'package:autonomy_flutter/service/canvas_client_service_v2.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SleepModeIndicator extends StatefulWidget {
  const SleepModeIndicator({required this.isSleeping, super.key});
  final bool isSleeping;

  @override
  State<SleepModeIndicator> createState() => _SleepModeIndicatorState();
}

class _SleepModeIndicatorState extends State<SleepModeIndicator>
    with SingleTickerProviderStateMixin {
  static const _processingAnimationDuration = Duration(milliseconds: 150);
  static const _pressedScale = 0.6;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: _processingAnimationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.2,
      end: _pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    final connectedDevice = BluetoothDeviceManager().castingBluetoothDevice;
    if (connectedDevice == null) {
      return;
    }

    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    // Animate while processing (until the command completes).
    _animationController.repeat(reverse: true);

    try {
      await injector<CanvasClientServiceV2>().setSleepMode(
        connectedDevice,
        !widget.isSleeping,
      );
    } catch (e, st) {
      log.warning('[SleepModeIndicator] setSleepMode failed: $e', st);
    } finally {
      if (!mounted) {
        return;
      }

      _animationController
        ..stop()
        ..reset();

      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: SleepModeIndicatorTokens.size.toDouble(),
              height: SleepModeIndicatorTokens.size.toDouble(),
              padding: EdgeInsets.all(SleepModeIndicatorTokens.padding.toDouble()),
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isSleeping
                      ? SleepModeIndicatorTokens.bgInactiveColor
                      : SleepModeIndicatorTokens.bgActiveColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
