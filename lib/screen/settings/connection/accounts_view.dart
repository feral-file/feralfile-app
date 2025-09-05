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
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/screen/onboarding/view_address/view_existing_address.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/color_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/account_view.dart';
import 'package:autonomy_flutter/view/crypto_view.dart';
import 'package:autonomy_flutter/view/keep_alive_widget.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AccountsView extends StatefulWidget {
  const AccountsView({
    required this.isInSettingsPage,
    super.key,
    this.scrollController,
  });

  final bool isInSettingsPage;
  final ScrollController? scrollController;

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  String? _editingAccountKey;
  final TextEditingController _nameController = TextEditingController();
  final padding = ResponsiveLayout.pageEdgeInsets.copyWith(top: 0, bottom: 0);

  late final AccountsBloc _accountsBloc;
  final _addressService = injector<AddressService>();

  @override
  void initState() {
    super.initState();
    _accountsBloc = context.read<AccountsBloc>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<AccountsBloc, AccountsState>(
        bloc: _accountsBloc,
        listener: (context, state) {},
        builder: (context, state) {
          final walletAddresses = state.addresses;
          if (walletAddresses == null) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (walletAddresses.isEmpty) {
            return _emptyAddressListWidget();
          }

          if (!widget.isInSettingsPage) {
            return _noEditAddressesListWidget(walletAddresses);
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: widget.scrollController,
            // onReorder: (int oldIndex, int newIndex) {
            //   _accountsBloc.add(
            //     ChangeAccountOrderEvent(
            //       newOrder: newIndex,
            //       oldOrder: oldIndex,
            //     ),
            //   );
            // },
            itemCount: walletAddresses.length + 1,
            itemBuilder: (context, index) {
              if (index == walletAddresses.length) {
                return SizedBox(
                  height: 200,
                  key: ValueKey('end'),
                );
              }
              final address = walletAddresses[index];
              return KeepAliveWidget(
                key: ValueKey(address.key),
                child: _addressCard(context, address),
              );
            },
          );
        },
      );

  Widget _addressCard(BuildContext context, WalletAddress address) => Column(
        children: [
          Padding(
            padding: padding,
            child: Slidable(
              groupTag: 'accountsView',
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                dragDismissible: false,
                children: slidableActions(address),
              ),
              child: Column(
                children: [
                  if (_editingAccountKey == null ||
                      _editingAccountKey != address.key) ...[
                    _viewAddressItem(address),
                  ] else ...[
                    _editAccountItem(
                      address,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColor.auLightGrey),
        ],
      );

  List<CustomSlidableAction> slidableActions(
    WalletAddress address, {
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isHidden = address.isHidden;
    final actions = [
      CustomSlidableAction(
        backgroundColor: AppColor.secondarySpanishGrey,
        foregroundColor: theme.colorScheme.secondary,
        padding: EdgeInsets.zero,
        child: Semantics(
          label: '${address.key}_hide',
          child: SvgPicture.asset(
            isHidden ? 'assets/images/unhide.svg' : 'assets/images/hide.svg',
          ),
        ),
        onPressed: (_) async {
          await _addressService.setHiddenStatus(
            addresses: [address.address],
            isHidden: !isHidden,
          );
          _accountsBloc.add(GetAccountsEvent());
        },
      ),
      CustomSlidableAction(
        backgroundColor: AppColor.auGreyBackground,
        foregroundColor: theme.colorScheme.secondary,
        padding: EdgeInsets.zero,
        child: Semantics(
          label: '${address.name}_edit',
          child: SvgPicture.asset(
            'assets/images/rename_icon.svg',
            colorFilter: ColorFilter.mode(
              theme.colorScheme.secondary,
              BlendMode.srcIn,
            ),
          ),
        ),
        onPressed: (_) {
          setState(() {
            _nameController.text = address.name;
            _editingAccountKey = address.key;
          });
        },
      ),
      CustomSlidableAction(
        backgroundColor: isPrimary ? Colors.red.withOpacity(0.3) : Colors.red,
        foregroundColor: theme.colorScheme.secondary,
        padding: EdgeInsets.zero,
        onPressed: isPrimary
            ? null
            : (_) => _showDeleteAccountConfirmation(context, address),
        child: Opacity(
          opacity: isPrimary ? 0.3 : 1,
          child: Semantics(
            label: '${address.name}_delete',
            child: SvgPicture.asset('assets/images/trash.svg'),
          ),
        ),
      ),
    ];
    return actions;
  }

  Widget _noEditAddressesListWidget(List<WalletAddress> addresses) {
    const index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...addresses.map(
          (account) => Column(
            children: [
              Padding(
                padding: padding,
                child: _viewAddressItem(account),
              ),
              if (index < addresses.length)
                addOnlyDivider()
              else
                const SizedBox(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewAddressItem(WalletAddress address) => accountItem(
        context,
        address,
      );

  Widget _editAccountItem(WalletAddress address) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          LogoCrypto(
            cryptoType: address.cryptoType,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Semantics(
              label: '${address.name}_editing',
              child: TextField(
                autocorrect: false,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: theme.textTheme.ppMori700Black16,
                controller: _nameController,
                onSubmitted: (String value) async {
                  if (value.isEmpty) {
                    return;
                  }

                  await injector<AddressService>().nameAddress(address, value);
                  setState(() {
                    _editingAccountKey = null;
                  });
                  _accountsBloc.add(GetAccountsEvent());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyAddressListWidget() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'address_empty'.tr(),
              style: Theme.of(context).textTheme.ppMori400Black14,
            ),
            const SizedBox(height: 36),
            PrimaryButton(
              text: 'add_display_address'.tr(),
              onTap: () async {
                unawaited(
                  Navigator.of(context).popAndPushNamed(
                    AppRouter.viewExistingAddressPage,
                    arguments: ViewExistingAddressPayload(false),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(
    BuildContext pageContext,
    WalletAddress walletAddress,
  ) {
    final theme = Theme.of(context);
    var accountName = walletAddress.name;
    if (accountName.isEmpty) {
      accountName = walletAddress.name.mask(4);
    }

    unawaited(
      showModalBottomSheet(
        context: pageContext,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        constraints: BoxConstraints(
          maxWidth: ResponsiveLayout.isMobile
              ? double.infinity
              : Constants.maxWidthModalTablet,
        ),
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (context) => Container(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: theme.auGreyBackground,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'remove_account'.tr(),
                  style: theme.primaryTextTheme.ppMori700White24,
                ),
                const SizedBox(height: 40),
                RichText(
                  textScaler: MediaQuery.textScalerOf(context),
                  text: TextSpan(
                    style: theme.primaryTextTheme.ppMori400White14,
                    children: <TextSpan>[
                      TextSpan(
                        text: 'sure_remove_account'.tr(),
                        //'Are you sure you want to delete the account ',
                      ),
                      TextSpan(
                        text: '“$accountName”',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: '?',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                PrimaryButton(
                  text: 'remove'.tr(),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_deleteAccount(pageContext, walletAddress));
                  },
                ),
                const SizedBox(height: 10),
                OutlineButton(
                  onTap: () => Navigator.of(context).pop(),
                  text: 'cancel_dialog'.tr(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WalletAddress address,
  ) async {
    await _addressService.deleteAddress(address);
    _accountsBloc.add(GetAccountsEvent());
  }
}
