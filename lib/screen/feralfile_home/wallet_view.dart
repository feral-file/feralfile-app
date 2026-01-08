//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/feralfile_home/explore_wallet_bloc.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Widget displaying wallet count from secure storage
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

  @override
  void initState() {
    super.initState();
    _bloc = ExploreWalletBloc(ChannelService());
    _bloc.add(LoadWalletCountEvent());
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

              // Show simple wallet count message
              return SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.walletCount == 0
                              ? Icons.account_balance_wallet_outlined
                              : Icons.verified_user_outlined,
                          size: 64,
                          color: state.walletCount == 0
                              ? AppColor.auQuickSilver
                              : AppColor.feralFileHighlight,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          state.walletCount == 0
                              ? 'No wallets found'
                              : state.walletCount == 1
                                  ? 'You have 1 wallet that can be recovered'
                                  : 'You have ${state.walletCount} wallets that can be recovered',
                          style: theme.textTheme.ppMori700White16,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: theme.textTheme.ppMori400Grey14,
                            children: state.walletCount == 0
                                ? [
                                    const TextSpan(
                                      text:
                                          'No wallets found in secure storage.',
                                    ),
                                  ]
                                : [
                                    const TextSpan(
                                      text:
                                          'These wallets are stored in secure storage. For more information, please contact Feral File at ',
                                    ),
                                    TextSpan(
                                      text: 'support@feralfile.com',
                                      style: theme.textTheme.ppMori400Grey14
                                          .copyWith(
                                        decoration: TextDecoration.underline,
                                        color: AppColor.feralFileHighlight,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          const href =
                                              'mailto:support@feralfile.com';
                                          launchUrlString(href);
                                        },
                                    ),
                                    const TextSpan(
                                      text: '.',
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
