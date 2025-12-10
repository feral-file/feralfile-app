import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';

class NoPairingDeviceDialog extends StatelessWidget {
  const NoPairingDeviceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Image.asset('assets/images/ff_device.png'),
                    const SizedBox(height: 20),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Meet FF1',
                          style: theme.textTheme.small.copyWith(
                            color: PrimitivesTokens.colorsBlack,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The art computer by Feral File.\nMade to play digital art on any screen.',
                          style: theme.textTheme.small.copyWith(
                            color: PrimitivesTokens.colorsBlack,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Column(
                      children: [
                        IntrinsicWidth(
                          child: PrimaryButton(
                            elevatedPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 11,
                            ),
                            padding: EdgeInsets.zero,
                            text: r'Preorder your FF1, $450 ',
                            textStyle: theme.textTheme.small.copyWith(
                              color: PrimitivesTokens.colorsBlack,
                            ),
                            rightIcon: SvgPicture.asset(
                              'assets/images/arrow_right.svg',
                              width: 12.23,
                              height: 10,
                              colorFilter: const ColorFilter.mode(
                                PrimitivesTokens.colorsBlack,
                                BlendMode.srcIn,
                              ),
                            ),
                            onTap: () {
                              final uri =
                                  Uri.parse('https://feralfile.com/install');
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Now in stock and shipping',
                          style: theme.textTheme.small.copyWith(
                            color: PrimitivesTokens.colorsInactive,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 40,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'A computer with one purpose.',
                          style: theme.textTheme.small.copyWith(
                            color: PrimitivesTokens.colorsGrey,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'We made FF1 because we needed it. Other screens, apps, and computers fall short for displaying complex computational art—they glitch, lag, or require hacks. FF1 is a dedicated tool that runs these works smoothly and reliably. — Sean Moss-Pultz',
                          style: theme.textTheme.h2.copyWith(
                            color: PrimitivesTokens.colorsBlack,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
