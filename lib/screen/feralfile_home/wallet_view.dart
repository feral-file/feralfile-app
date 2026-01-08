//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/model/persona_wallet.dart';
import 'package:autonomy_flutter/model/wallet_address.dart';
import 'package:autonomy_flutter/nft_collection/nft_collection.dart';
import 'package:autonomy_flutter/screen/feralfile_home/explore_wallet_bloc.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Widget displaying full wallets (personas) with recovery phrases in the Explore tab
class ExploreWalletView extends StatefulWidget {
  const ExploreWalletView({
    required this.header,
    super.key,
  });

  final Widget header;

  @override
  State<ExploreWalletView> createState() => ExploreWalletViewState();
}

class ExploreWalletViewState extends State<ExploreWalletView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final ExploreWalletBloc _bloc;
  final Set<String> _visibleRecoveryPhrases = {};

  @override
  void initState() {
    super.initState();
    _bloc = ExploreWalletBloc(
      ChannelService(),
      () async {
        try {
          // Try to get addresses from nft collection database
          final addresses =
              await NftCollection.addressService.getAllAddresses();
          return addresses
              .map((e) => WalletAddress(
                    address: e.address,
                    createdAt: e.lastRefreshedTime,
                  ))
              .toList();
        } catch (e) {
          // If address service not initialized or error, return empty list
          // Personas can still be displayed without addresses
          return [];
        }
      },
    );
    _bloc.add(LoadPersonaWalletsEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _toggleRecoveryPhrase(String uuid) {
    setState(() {
      if (_visibleRecoveryPhrases.contains(uuid)) {
        _visibleRecoveryPhrases.remove(uuid);
      } else {
        _visibleRecoveryPhrases.add(uuid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return BlocProvider.value(
      value: _bloc,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
          SliverToBoxAdapter(
            child: widget.header,
          ),
          BlocBuilder<ExploreWalletBloc, ExploreWalletState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (state.personaWallets.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'No full wallets found',
                              style: theme.textTheme.ppMori400White14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Full wallets (with recovery phrases) will appear here if you have created them.',
                              style: theme.textTheme.ppMori400Grey12,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final persona = state.personaWallets[index];
                    final isRecoveryPhraseVisible =
                        _visibleRecoveryPhrases.contains(persona.uuid);

                    return _personaWalletCard(
                      context,
                      persona,
                      isRecoveryPhraseVisible,
                    );
                  },
                  childCount: state.personaWallets.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _personaWalletCard(
    BuildContext context,
    PersonaWallet persona,
    bool isRecoveryPhraseVisible,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColor.auGreyBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet name and UUID
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      persona.displayName,
                      style: theme.textTheme.ppMori700Black16,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UUID: ${persona.uuid.substring(0, 8)}...',
                      style: theme.textTheme.ppMori400Grey14,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Note: Addresses cannot be reliably associated with personas
          // (WalletAddress model has no personaUUID field)
          // Removing address display for accuracy

          // Recovery phrase section
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColor.auLightGrey,
          ),
          const SizedBox(height: 12),

          // Toggle recovery phrase button
          GestureDetector(
            onTap: () => _toggleRecoveryPhrase(persona.uuid),
            child: Row(
              children: [
                Text(
                  'recovery_phrase'.tr(),
                  style: theme.textTheme.ppMori700Black14,
                ),
                const Spacer(),
                SvgPicture.asset(
                  isRecoveryPhraseVisible
                      ? 'assets/images/hide.svg'
                      : 'assets/images/unhide.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.secondary,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),

          // Recovery phrase display
          if (isRecoveryPhraseVisible) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColor.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColor.auLightGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: persona.mnemonic.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final word = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColor.auLightGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$index. $word',
                          style: theme.textTheme.ppMori400Black14,
                        ),
                      );
                    }).toList(),
                  ),
                  if (persona.passphrase != null &&
                      persona.passphrase!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColor.auLightGrey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'passphrase'.tr(),
                      style: theme.textTheme.ppMori400Grey14,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      persona.passphrase!,
                      style: theme.textTheme.ppMori400Black14,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
