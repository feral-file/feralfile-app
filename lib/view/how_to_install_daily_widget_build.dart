import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class HowToInstallDailyWidget extends StatelessWidget {
  const HowToInstallDailyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('How to install the Feral File Daily Widget',
                    style: theme.textTheme.ppMori700White24
                        .copyWith(fontSize: 22)),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 10),
                  child: SvgPicture.asset(
                    'assets/images/circle_close.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
              color: AppColor.primaryBlack,
              padding: EdgeInsets.all(16),
              child:
                  Center(child: Image.asset('assets/images/home_screen.png'))),
          const SizedBox(height: 16),
          _instruction(context),
        ],
      ),
    );
  }

  Widget _instruction(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.ppMori400White16;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. ', style: style),
            Expanded(
              child: Text(
                'From the Home Screen, touch and hold a widget or an empty area until the apps jiggle.',
                style: style,
                maxLines: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('2. ', style: style),
            Expanded(
              child: Text('Tap the Add button + in the upper-left corner.',
                  style: style, maxLines: 3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('3. ', style: style),
            Expanded(
              child: Text(
                  'Select the Feral File widget, choose a widget size, then tap Add Widget.',
                  style: style,
                  maxLines: 3),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4. ', style: style),
            Expanded(child: Text('Tap Done.', style: style, maxLines: 3)),
          ],
        ),
      ],
    );
  }
}
