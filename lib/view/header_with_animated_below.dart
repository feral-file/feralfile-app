import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class HeaderWithAnimated extends StatefulWidget {
  final Widget header;
  final Widget child;
  final ValueListenable<bool> isExpandedListenable;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve curve;
  final Curve? reverseCurve;
  final AlignmentGeometry alignment;

  const HeaderWithAnimated({
    required this.header,
    required this.child,
    required this.isExpandedListenable,
    this.duration = const Duration(milliseconds: 150),
    this.reverseDuration,
    this.curve = Curves.linear,
    this.reverseCurve,
    this.alignment = Alignment.bottomCenter,
    super.key,
  });

  @override
  State<HeaderWithAnimated> createState() => _HeaderWithAnimatedState();
}

class _HeaderWithAnimatedState extends State<HeaderWithAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.reverseDuration ?? widget.duration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: widget.reverseCurve ?? widget.curve,
    );

    // initialize from current listenable value
    _controller.value = widget.isExpandedListenable.value ? 1 : 0;

    widget.isExpandedListenable.addListener(_onExpandedChanged);
  }

  void _onExpandedChanged() {
    if (widget.isExpandedListenable.value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant HeaderWithAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.reverseDuration != widget.reverseDuration) {
      _controller.duration = widget.duration;
      _controller.reverseDuration = widget.reverseDuration ?? widget.duration;
    }
    if (oldWidget.curve != widget.curve ||
        oldWidget.reverseCurve != widget.reverseCurve) {
      _progress = CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
        reverseCurve: widget.reverseCurve ?? widget.curve,
      );
    }
    if (oldWidget.isExpandedListenable != widget.isExpandedListenable) {
      oldWidget.isExpandedListenable.removeListener(_onExpandedChanged);
      _controller.value = widget.isExpandedListenable.value ? 1 : 0;
      widget.isExpandedListenable.addListener(_onExpandedChanged);
    }
  }

  @override
  void dispose() {
    widget.isExpandedListenable.removeListener(_onExpandedChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.header,
        AnimatedBuilder(
          animation: _progress,
          builder: (context, child) {
            final double factor = _progress.value.clamp(0, 1);
            return ClipRect(
              child: Align(
                alignment: widget.alignment,
                heightFactor: factor == 0 ? 0.0001 : factor,
                child: Opacity(
                  opacity: factor,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1.0),
                      end: Offset.zero,
                    ).animate(_progress),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ],
    );
  }
}
