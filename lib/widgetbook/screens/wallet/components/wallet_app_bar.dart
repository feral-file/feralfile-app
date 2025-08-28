import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:widgetbook/widgetbook.dart';

class WalletAppBarComponent extends WidgetbookComponent {
  WalletAppBarComponent()
      : super(
          name: 'Wallet App Bar',
          useCases: [
            WidgetbookUseCase(
              name: 'Default',
              builder: (context) => getBackAppBar(
                context,
                title: 'Wallet',
                onBack: () {},
                icon: Semantics(
                  label: 'address_menu',
                  child: SvgPicture.asset(
                    'assets/images/more_circle.svg',
                    width: 22,
                    colorFilter: const ColorFilter.mode(
                      AppColor.primaryBlack,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                action: () {},
              ),
            ),
          ],
        );
}
