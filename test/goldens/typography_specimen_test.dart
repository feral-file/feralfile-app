import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('Typography Specimen', () {
    testGoldens('All typography styles at 1.0x scale', (tester) async {
      await tester.pumpWidgetBuilder(
        Builder(
          builder: (context) {
            return Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Display 40px',
                    style: AppTypography.display(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'H1 28px - Page titles',
                    style: AppTypography.h1(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'H2 22px - Section headers',
                    style: AppTypography.h2(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'H3 18px - Component headers',
                    style: AppTypography.h3(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Body 16px - Default body text (this is the default)',
                    style: AppTypography.body(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Body Bold 16px - Emphasized text',
                    style: AppTypography.bodyBold(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Body Small 14px - Secondary labels',
                    style: AppTypography.bodySmall(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Body Small Bold 14px',
                    style: AppTypography.bodySmallBold(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Caption 12px - Low-priority metadata',
                    style: AppTypography.caption(context).grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Caption Bold 12px',
                    style: AppTypography.captionBold(context).grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mono 16px - 0x1234...5678',
                    style: AppTypography.mono(context).black,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mono Small 14px - 0xabcd',
                    style: AppTypography.monoSmall(context).black,
                  ),
                ],
              ),
            );
          },
        ),
        surfaceSize: const Size(400, 800),
        wrapper: materialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'typography_specimen_1.0x');
    });

    testGoldens('All typography styles at 1.3x scale (accessibility)',
        (tester) async {
      await tester.pumpWidgetBuilder(
        MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.3),
            size: Size(400, 800),
          ),
          child: Builder(
            builder: (context) {
              return Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Display 40px → 52px',
                      style: AppTypography.display(context).black,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'H1 28px → 36px',
                      style: AppTypography.h1(context).black,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'H2 22px → 29px',
                      style: AppTypography.h2(context).black,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Body 16px → 21px (default)',
                      style: AppTypography.body(context).black,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Caption 12px → 16px',
                      style: AppTypography.caption(context).grey,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        surfaceSize: const Size(400, 800),
        wrapper: materialAppWrapper(),
      );
      await screenMatchesGolden(tester, 'typography_specimen_1.3x');
    });
  });
}

