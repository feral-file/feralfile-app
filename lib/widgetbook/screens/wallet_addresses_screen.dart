import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/settings/connection/accounts_view.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../mock/mock_injector.dart';

class WalletAddressesScreen extends StatelessWidget {
  const WalletAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    MockInjector.setup();
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'wallet'.tr(),
        onBack: () {
          Navigator.of(context).pop();
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: ResponsiveLayout.pageEdgeInsetsWithSubmitButton.bottom,
          ),
          child: BlocProvider<AccountsBloc>(
            create: (context) => MockInjector.get<AccountsBloc>(),
            child: const AccountsView(
              isInSettingsPage: true,
            ),
          ),
        ),
      ),
    );
  }
}
