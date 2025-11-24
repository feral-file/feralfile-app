//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/llm_text_input.dart';
import 'package:flutter/material.dart';

class BottomInteractionBar extends StatefulWidget {
  const BottomInteractionBar({super.key});

  @override
  State<BottomInteractionBar> createState() => _BottomInteractionBarState();
}

class _BottomInteractionBarState extends State<BottomInteractionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  double _scrollOffset = 0; // Negative value means scrolled up (hidden)
  double _previousScrollPosition = 0;
  static const double _maxScrollOffset = 200; // Max pixels to scroll up

  bool get _shouldShow => _isShowing && _scrollOffset == 0.0;
  bool _isShowing = false;

  @override
  void initState() {
    super.initState();
    _isShowing = nowDisplayingShowing.value;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _isShowing ? 1.0 : 0.0,
    );
    // Update animation when shouldShow changes
    if (_isShowing) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    // Listen to nowDisplayingShowing changes
    nowDisplayingShowing.addListener(_onShowingChanged);
  }

  void _onShowingChanged() {
    final newValue = nowDisplayingShowing.value;
    if (_isShowing != newValue && mounted) {
      setState(() {
        _isShowing = newValue;
        if (_isShowing) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    nowDisplayingShowing.removeListener(_onShowingChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep widget visible during animation even if shouldShow is false
    if (!_isShowing && _animationController.value == 0.0) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder(
      valueListenable: isNowDisplayingBarExpanded,
      builder: (context, isExpanded, child) {
        final paddingBottom = MediaQuery.of(context).padding.bottom;
        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollUpdate,
          child: Transform.translate(
            offset: Offset(0, _scrollOffset),
            child: Stack(
              children: [
                // LLMTextInput
                if (!isExpanded)
                  Positioned(
                    bottom: paddingBottom +
                        UIConstants.nowDisplayingBarBottomPadding +
                        NowPlayingBarTokens.collapseHeight,
                    left: 0,
                    right: 0,
                    child: _buildAnimatedWrapper(
                      child: const Material(
                        color: Colors.transparent,
                        child: LLMTextInput(),
                      ),
                    ),
                  ),

                // NowDisplayingBar
                Positioned(
                  bottom:
                      paddingBottom + UIConstants.nowDisplayingBarBottomPadding,
                  left: ResponsiveLayout.paddingHorizontal,
                  right: ResponsiveLayout.paddingHorizontal,
                  child: _buildAnimatedWrapper(
                    child: FadeTransition(
                      opacity: _animationController,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(
                            0,
                            paddingBottom / kNowDisplayingHeight,
                          ),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: const NowDisplayingBar(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedWrapper({required Widget child}) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: _shouldShow ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _shouldShow ? 1 : 0,
        child: child,
      ),
    );
  }

  bool _handleScrollUpdate(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final currentPosition = notification.metrics.pixels;
    final scrollDelta = currentPosition - _previousScrollPosition;

    // Always reset to visible when at top of scroll
    if (currentPosition <= 0) {
      if (_scrollOffset != 0.0 && mounted) {
        setState(() {
          _scrollOffset = 0.0;
          _previousScrollPosition = currentPosition;
        });
      } else {
        _previousScrollPosition = currentPosition;
      }
      return false;
    }

    // Update scroll offset based on scroll direction
    if (scrollDelta.abs() > 2) {
      if (mounted) {
        setState(() {
          // Scrolling down (positive delta) -> move up (negative offset)
          if (scrollDelta > 0) {
            _scrollOffset = (_scrollOffset - scrollDelta * 0.8)
                .clamp(-_maxScrollOffset, 0.0);
          }
          // Scrolling up (negative delta) -> move down (positive offset)
          else {
            _scrollOffset = (_scrollOffset - scrollDelta * 0.8)
                .clamp(-_maxScrollOffset, 0.0);
          }
          _previousScrollPosition = currentPosition;
        });
      }
    }

    return false;
  }
}
