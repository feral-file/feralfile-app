//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/au_text_field.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class NameViewOnlyAddressPage extends StatefulWidget {
  const NameViewOnlyAddressPage({required this.address, super.key});

  final WalletAddress address;

  @override
  State<NameViewOnlyAddressPage> createState() =>
      _NameViewOnlyAddressPageState();
}

class _NameViewOnlyAddressPageState extends State<NameViewOnlyAddressPage> {
  final TextEditingController _nameController = TextEditingController();

  bool _isSavingAliasDisabled = false;

  void saveAliasButtonChangedState() {
    setState(() {
      _isSavingAliasDisabled = !_isSavingAliasDisabled;
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.address.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _deleteConnection(BuildContext context) async {
    await injector<AddressService>().deleteAddress(widget.address);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: getBackAppBar(
          context,
          title: 'add_display_address'.tr(),
          onBack: () async {
            await _deleteConnection(context);
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop();
          },
        ),
        body: Container(
          margin: ResponsiveLayout.pageHorizontalEdgeInsetsWithSubmitButton,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      addTitleSpace(),
                      Text(
                        'aa_you_can_add'.tr(),
                        style: theme.textTheme.ppMori400Black14,
                      ),
                      const SizedBox(height: 15),
                      AuTextField(
                        labelSemantics: 'enter_alias_link',
                        title: '',
                        placeholder: 'enter_alias'.tr(),
                        controller: _nameController,
                        onChanged: (valueChanged) {
                          if (_nameController.text.trim().isEmpty !=
                              _isSavingAliasDisabled) {
                            saveAliasButtonChangedState();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: PrimaryAsyncButton(
                      text: 'continue'.tr(),
                      onTap: _isSavingAliasDisabled
                          ? null
                          : () async {
                              final newConnection = widget.address
                                  .copyWith(name: _nameController.text);

                              await injector<AddressService>().insertAddress(
                                  newConnection,
                                  checkAddressDuplicated: false);
                              _doneNaming();
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _doneNaming() {
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == AppRouter.homePage ||
          route.settings.name == AppRouter.homePage ||
          route.settings.name == AppRouter.walletPage,
    );
  }
}
