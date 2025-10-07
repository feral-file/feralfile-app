import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HeaderWithAnimated extends StatefulWidget {
  final Widget header;
  final Widget child;
  final ValueListenable<bool> isExpandedListenable;
  final double? maxHeight;

  const HeaderWithAnimated({
    required this.header,
    required this.child,
    required this.isExpandedListenable,
    this.maxHeight,
    super.key,
  });

  @override
  State<HeaderWithAnimated> createState() => _HeaderWithAnimatedState();
}

class _HeaderWithAnimatedState extends State<HeaderWithAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Create animation curve
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    widget.isExpandedListenable.addListener(_onExpandedChanged);

    // Set initial animation state
    if (widget.isExpandedListenable.value) {
      _animationController.value = 1.0;
    }
  }

  void _onExpandedChanged() {
    if (widget.isExpandedListenable.value) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant HeaderWithAnimated oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpandedListenable != widget.isExpandedListenable) {
      oldWidget.isExpandedListenable.removeListener(_onExpandedChanged);
      widget.isExpandedListenable.addListener(_onExpandedChanged);

      // Update animation state for new listener
      if (widget.isExpandedListenable.value) {
        _animationController.value = 1.0;
      } else {
        _animationController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    widget.isExpandedListenable.removeListener(_onExpandedChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxHeight,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return SizedBox(
                  height: widget.maxHeight! * (1 - _animation.value),
                );
              },
            ),
          ),
          widget.header,
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: _animation.value,
                  child: widget.child,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
