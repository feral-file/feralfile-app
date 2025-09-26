import 'dart:async';

import 'package:flutter/material.dart';

/// A simple data model for tooltip content and its display duration.
class ToolTip {
  /// The text to display.
  final String text;

  /// How long this tooltip stays visible before switching to the next one.
  final Duration duration;

  const ToolTip({required this.text, required this.duration});
}

/// A widget that cycles through a list of [ToolTip]s and animates the
/// transition with a fade effect on each change.
class AnimatedCycledTooltipController {
  VoidCallback? _pause;
  VoidCallback? _resume;
  VoidCallback? _next;
  VoidCallback? _previous;
  void Function(int index)? _jumpTo;

  bool get isAttached =>
      _pause != null || _resume != null || _next != null || _previous != null;

  void _attach({
    required VoidCallback pause,
    required VoidCallback resume,
    required VoidCallback next,
    required VoidCallback previous,
    required void Function(int index) jumpTo,
  }) {
    _pause = pause;
    _resume = resume;
    _next = next;
    _previous = previous;
    _jumpTo = jumpTo;
  }

  void _detach() {
    _pause = null;
    _resume = null;
    _next = null;
    _previous = null;
    _jumpTo = null;
  }

  void pause() => _pause?.call();
  void resume() => _resume?.call();
  void next() => _next?.call();
  void previous() => _previous?.call();
  void jumpTo(int index) => _jumpTo?.call(index);
}

class AnimatedCycledTooltip extends StatefulWidget {
  /// List of tooltips to cycle through. Must not be empty.
  final List<ToolTip> tooltips;

  /// Optional style for the tooltip text.
  final TextStyle? style;

  /// Alignment of the text widget.
  final AlignmentGeometry alignment;

  /// Curve used for the transition animation.
  final Curve transitionCurve;

  /// The duration of the transition animation itself (not the display time).
  final Duration transitionDuration;

  /// Optional text alignment for multi-line tooltips.
  final TextAlign textAlign;

  /// Optional external controller to pause/resume or navigate manually.
  final AnimatedCycledTooltipController? controller;

  const AnimatedCycledTooltip({
    super.key,
    required this.tooltips,
    this.style,
    this.alignment = Alignment.center,
    this.transitionCurve = Curves.easeInOut,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.textAlign = TextAlign.center,
    this.controller,
  });

  @override
  State<AnimatedCycledTooltip> createState() => _AnimatedCycledTooltipState();
}

class _AnimatedCycledTooltipState extends State<AnimatedCycledTooltip> {
  int _currentIndex = 0;
  Timer? _timer;
  bool _isPaused = false;
  late bool _ownsController;
  AnimatedCycledTooltipController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
    _startOrScheduleNext();
  }

  @override
  void didUpdateWidget(covariant AnimatedCycledTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart cycle if the tooltips list changed or became shorter/longer.
    if (oldWidget.tooltips != widget.tooltips) {
      // Keep index within bounds when list shrinks.
      if (widget.tooltips.isNotEmpty) {
        _currentIndex %= widget.tooltips.length;
      } else {
        _currentIndex = 0;
      }
      _restartTimer();
    }

    // Handle controller swapping
    if (oldWidget.controller != widget.controller) {
      _detachController();
      _initController();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _detachController();
    super.dispose();
  }

  void _initController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AnimatedCycledTooltipController();
    _controller!._attach(
      pause: _pause,
      resume: _resume,
      next: _advanceIndex,
      previous: _previousIndex,
      jumpTo: _jumpTo,
    );
  }

  void _detachController() {
    _controller?._detach();
    if (_ownsController) {
      _controller = null;
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _startOrScheduleNext();
  }

  void _startOrScheduleNext() {
    if (widget.tooltips.isEmpty) return;
    if (_isPaused) return;

    // Schedule switch according to current tooltip's duration.
    final current = widget.tooltips[_currentIndex];
    _timer = Timer(current.duration, _advanceIndex);
  }

  void _advanceIndex() {
    if (!mounted || widget.tooltips.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.tooltips.length;
    });
    _startOrScheduleNext();
  }

  void _previousIndex() {
    if (!mounted || widget.tooltips.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1) % widget.tooltips.length;
      if (_currentIndex < 0) {
        _currentIndex += widget.tooltips.length;
      }
    });
    _restartTimer();
  }

  void _jumpTo(int index) {
    if (!mounted || widget.tooltips.isEmpty) return;
    if (index < 0 || index >= widget.tooltips.length) return;
    setState(() {
      _currentIndex = index;
    });
    _restartTimer();
  }

  void _pause() {
    _isPaused = true;
    _timer?.cancel();
  }

  void _resume() {
    if (!_isPaused) return;
    _isPaused = false;
    _startOrScheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tooltips.isEmpty) {
      return const SizedBox.shrink();
    }

    final tooltip = widget.tooltips[_currentIndex];

    final child = AnimatedSwitcher(
      duration: widget.transitionDuration,
      switchInCurve: widget.transitionCurve,
      switchOutCurve: widget.transitionCurve,
      transitionBuilder: (child, animation) {
        final bool isIncoming = child.key == ValueKey<int>(_currentIndex);

        final Animation<double> base =
            isIncoming ? animation : ReverseAnimation(animation);
        final curved = CurvedAnimation(
          parent: base,
          curve: widget.transitionCurve,
          reverseCurve: widget.transitionCurve,
        );

        final slideTweenIn = Tween<Offset>(
          begin: const Offset(0.0, 0.25),
          end: Offset.zero,
        );

        final slideTweenOut = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.0, -0.25),
        );

        final position =
            (isIncoming ? slideTweenIn : slideTweenOut).animate(curved);
        // return child;

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: position,
            child: child,
          ),
        );
      },
      child: Text(
        key: ValueKey<int>(_currentIndex),
        tooltip.text,
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Align(
        alignment: widget.alignment,
        heightFactor: 1,
        child: child,
      ),
    );
  }
}
