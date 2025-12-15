//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/screen/settings/preferences/preferences_view.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PreferencePage extends StatefulWidget {
  const PreferencePage({super.key});

  @override
  State<PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  final GlobalKey<State> _preferenceKey = GlobalKey();

  @override
  void initState() {
    context.read<AccountsBloc>().add(GetAccountsEvent());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'preferences'.tr(),
        onBack: () {
          Navigator.of(context).pop();
        },
        backgroundColor: AppColor.auGreyBackground,
        isWhite: false,
      ),
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Column(
          children: [
            addTitleSpace(),
            Column(
              children: [
                PreferenceView(
                  key: _preferenceKey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
