//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/environment.dart';
import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/database/app_data_manager.dart';
import 'package:autonomy_flutter/design/build/components/CommandDot.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/util/bluetooth_device_helper.dart';
import 'package:autonomy_flutter/util/custom_route_observer.dart';
import 'package:autonomy_flutter/view/now_displaying/dragable_sheet_view.dart';
import 'package:autonomy_flutter/view/now_displaying/now_displaying_bar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/llm_text_input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Widget that wraps LLMTextInput and NowDisplayingBar with shared scroll-based visibility
class BottomInteractionBar extends StatefulWidget {
  const BottomInteractionBar({super.key});

  @override
  State<BottomInteractionBar> createState() => _BottomInteractionBarState();
}

class _BottomInteractionBarState extends State<BottomInteractionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Widget heights (constants)
  static final double _llmInputHeight = LLMTextInputTokens.padding * 2 +
      LLMTextInputTokens.llmPaddingVertical * 2 +
      CommandDotTokens.height.toDouble();
  static final double _nowDisplayingBarHeight =
      NowPlayingBarTokens.collapseHeight.toDouble();

  // Keys to measure actual widget heights
  final GlobalKey _nowDisplayingBarKey = GlobalKey();
  double _actualNowDisplayingBarHeight = _nowDisplayingBarHeight;

  bool _isShowing = false;

  /// Check if explore bar should be shown
  /// Returns true if:
  /// - Dev override is enabled (ENABLE_EXPLORE_DEV env var or kDebugMode), OR
  /// - Beta features are enabled AND explore bar is enabled
  bool _shouldShowExploreBar() {
    if (Environment.enableExploreDev || kDebugMode) {
      return true;
    }

    final appSettingsStorageService =
        injector<AppDataManager>().appSettingsStorageService;
    return appSettingsStorageService.isBetaFeaturesEnabled &&
        appSettingsStorageService.isExploreBarEnabled;
  }

  bool _shouldShowNowDisplayingBar() {
    return BluetoothDeviceManager().castingBluetoothDevice != null;
  }

  void _updateHeights() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      double? newBarHeight;

      final barContext = _nowDisplayingBarKey.currentContext;
      if (barContext != null) {
        final renderBox = barContext.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          newBarHeight = renderBox.size.height;
        }
      }
      newBarHeight ??= _nowDisplayingBarHeight;

      if (newBarHeight != _actualNowDisplayingBarHeight) {
        setState(() {
          _actualNowDisplayingBarHeight = newBarHeight!;
        });
      }
    });
  }

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

    // Listen to casting device changes
    BluetoothDeviceManager()
        .castingBluetoothDeviceNotifier
        .addListener(_onCastingDeviceChanged);
  }

  void _onShowingChanged() {
    final newValue = nowDisplayingShowing.value;
    if (_isShowing != newValue && mounted) {
      setState(() {
        _isShowing = newValue;
        if (_isShowing) {
          _animationController.forward();
        } else {
          if (CustomRouteObserver.bottomSheetVisibility.value) {
            _animationController.value = 0.0;
          } else {
            _animationController.reverse();
          }
        }
      });
    }
  }

  void _onCastingDeviceChanged() {
    if (mounted) {
      setState(() {
        // Rebuild to update _shouldShowNowDisplayingBar()
      });
    }
  }

  @override
  void dispose() {
    nowDisplayingShowing.removeListener(_onShowingChanged);
    BluetoothDeviceManager()
        .castingBluetoothDeviceNotifier
        .removeListener(_onCastingDeviceChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder to automatically rebuild when animation value changes
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Keep widget visible during animation even if shouldShow is false
        if (!_isShowing && _animationController.value == 0.0) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder(
          valueListenable: isNowDisplayingBarExpanded,
          builder: (context, isNowDisplayingBarExpanded, child) {
            final paddingBottom = MediaQuery.of(context).padding.bottom;
            _updateHeights();

            return Stack(
              children: [
                IgnorePointer(
                  child: Container(
                    color: Colors.transparent,
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                  ),
                ),
                // Gradient (only on home page)
                if ((_shouldShowExploreBar() ||
                        _shouldShowNowDisplayingBar()) &&
                    !isNowDisplayingBarExpanded)
                  ValueListenableBuilder(
                    valueListenable: CustomRouteObserver.currentRoute,
                    builder: (context, route, child) {
                      if (route?.settings.name == AppRouter.homePage) {
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                height: (_shouldShowExploreBar()
                                        ? _llmInputHeight
                                        : 0) +
                                    (_shouldShowNowDisplayingBar()
                                        ? _nowDisplayingBarHeight
                                        : 0) +
                                    paddingBottom +
                                    100,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      PrimitivesTokens.colorsDarkGrey,
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0.0, 0.37],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                // LLMTextInput
                if (_shouldShowExploreBar() && !isNowDisplayingBarExpanded)
                  Positioned(
                    bottom: paddingBottom +
                        UIConstants.nowDisplayingBarBottomPadding +
                        (_shouldShowNowDisplayingBar()
                            ? _nowDisplayingBarHeight
                            : 0),
                    left: 0,
                    right: 0,
                    child: _animateVisibility(
                      child: const Material(
                        color: Colors.transparent,
                        child: LLMTextInput(),
                      ),
                      slideBegin: _calculateSlideBegin(
                        paddingBottom,
                        _llmInputHeight,
                      ),
                    ),
                  ),

                // NowDisplayingBar
                if (_shouldShowNowDisplayingBar())
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    bottom: paddingBottom +
                        UIConstants.nowDisplayingBarBottomPadding,
                    left: ResponsiveLayout.paddingHorizontal,
                    right: ResponsiveLayout.paddingHorizontal,
                    child: _animateVisibility(
                      child: Container(
                        key: _nowDisplayingBarKey,
                        child: const NowDisplayingBar(),
                      ),
                      slideBegin: _calculateSlideBegin(
                        paddingBottom,
                        _actualNowDisplayingBarHeight,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Calculate slide begin offset to achieve the same pixel distance for all widgets
  /// Offset is a fraction of widget height, so we calculate: pixelDistance / widgetHeight
  static Offset _calculateSlideBegin(
    double paddingBottom,
    double widgetHeight,
  ) {
    final slideDistance = paddingBottom +
        UIConstants.nowDisplayingBarBottomPadding +
        _nowDisplayingBarHeight +
        _llmInputHeight;
    final offsetY = slideDistance / widgetHeight;
    return Offset(0, offsetY);
  }

  SlideTransition _animateVisibility({
    required Widget child,
    required Offset slideBegin,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: slideBegin,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        ),
      ),
      child: child,
    );
  }
}
