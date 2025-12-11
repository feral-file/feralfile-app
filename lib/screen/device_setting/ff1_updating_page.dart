import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/material.dart';

class FF1Updating extends StatelessWidget {
  const FF1Updating({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // User tried to use hardware back button or swipe back gesture
          // Navigate to home instead of popping
          injector<NavigationService>().replaceAllAndPushNamed(
            AppRouter.homePage,
          );
        }
      },
      child: Scaffold(
        appBar: SetupAppBar(
          onBack: () {
            injector<NavigationService>().replaceAllAndPushNamed(
              AppRouter.homePage,
            );
          },
          withDivider: false,
        ),
        backgroundColor: PrimitivesTokens.colorsDarkGrey,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/ff_logo.png',
                      width: 139,
                      height: 92.67,
                    ),
                    const SizedBox(height: 85),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Updating FF1',
                            style: Theme.of(context).textTheme.h3,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '''This update typically takes 5–10 min and FF1 may restart.\n\nKeep it powered and connected. Setup will continue when ready.''',
                            style: Theme.of(context).textTheme.small,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Positioned(
                //   bottom: 15,
                //   left: 0,
                //   right: 0,
                //   child: PrimaryAsyncButton(
                //     onTap: () async {
                //       // check the device status
                //       // if the device is updated, show the FF1 settings page
                //     },
                //     text: 'Check again',
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
