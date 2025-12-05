//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:flutter/material.dart';

/// Debug-only overlay widget used to visually compare a live screen
/// against a reference image (typically a Figma export).
///
/// The [imagePath] is drawn on top of [child] using [InteractiveViewer]
/// so you can pan/zoom, while [IgnorePointer] ensures the overlay does not
/// block user interactions with the underlying UI.
class DebugOverlay extends StatelessWidget {
  DebugOverlay({
    super.key,
    required this.child,
    required this.imagePath,
  });

  final Widget child;
  final String imagePath;

  final TransformationController _transformationController =
      TransformationController();

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: shouldShowOverlay ? 16.0 : 1.0,
      child: Stack(
        children: [
          child,
          if (shouldShowOverlay)
            IgnorePointer(
              ignoring: true,
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.amber,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
