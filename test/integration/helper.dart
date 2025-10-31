import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class ScreenCapture {
  ScreenCapture(
    String path, {
    this.width = 1080, // Pixel 10 default width (physical px)
    this.height = 2400, // Pixel 10 default height (physical px)
    this.devicePixelRatio = 3.0, // Typical DPR for Pixel devices
  }) : _baseDir = 'test/integration/captures/${path.isEmpty ? '' : '$path/'}';

  final String _baseDir;
  final double width;
  final double height;
  final double devicePixelRatio;

  Future<void> capture(WidgetTester tester, String name) async {
    // Backup existing view settings
    final double oldDevicePixelRatio = tester.view.devicePixelRatio;
    final Size oldPhysicalSize = tester.view.physicalSize;

    // Apply requested screen configuration
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = Size(width, height);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final Finder target = find.byKey(const Key('shotRoot'));
    final double ratio = tester.view.devicePixelRatio;

    final renderObject = tester.firstRenderObject(target);
    final boundary = renderObject as RenderRepaintBoundary;

    try {
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: ratio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();
        final file = File('$_baseDir$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(pngBytes);
      });
    } finally {
      // Restore original view settings to avoid test side effects
      tester.view.devicePixelRatio = oldDevicePixelRatio;
      tester.view.physicalSize = oldPhysicalSize;
      await tester.pump();
    }
  }
}

/// Legacy helpers (kept for convenience)
Future<void> captureScreen(WidgetTester tester, String name) async {
  await ScreenCapture('').capture(tester, name);
}

Future<void> captureStep(WidgetTester tester, String name) async {
  await captureScreen(tester, name);
}
