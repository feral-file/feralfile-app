//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/database/indexer_database.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_bloc.dart';
import 'package:autonomy_flutter/screen/bloc/accounts/accounts_state.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/crypto_view.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget accountItem(
  BuildContext context,
  WalletAddress address, {
  FutureOr<void> Function()? onTap,
}) {
  final theme = Theme.of(context);
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    LogoCrypto(cryptoType: address.cryptoType, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        address.name,
                        style: theme.textTheme.ppMori700Black16,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (address.isHidden) ...[
                const SizedBox(width: 10),
                SvgPicture.asset(
                  'assets/images/hide.svg',
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.surface,
                    BlendMode.srcIn,
                  ),
                ),
              ],
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 10),
          BlocConsumer<AccountsBloc, AccountsState>(
            builder: (context, state) {
              final nftBalance = state.addressBalances[address.address] ?? '--';
              final style = theme.textTheme.ppMori400Grey14;
              return Row(
                children: [
                  Text(nftBalance, style: style),
                ],
              );
            },
            buildWhen: (previous, current) =>
                previous.addressBalances[address.address] !=
                current.addressBalances[address.address],
            listener: (BuildContext context, AccountsState state) {},
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectionArea(
                  child: Text(
                    address.address,
                    style: theme.textTheme.ppMori400Black14,
                    key: const Key('fullAccount_address'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<String> getNftBalance(
  String address,
) async {
  final tokenDao = injector<IndexerDatabaseAbstract>();
  final tokens = tokenDao.getAssetTokensByOwner(ownerAddress: address);
  final nftBalance =
      "${tokens.length} ${tokens.length == 1 ? 'nft'.tr() : 'nfts'.tr()}";

  return nftBalance;
}
