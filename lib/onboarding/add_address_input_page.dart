//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/onboarding/onboarding_add_address_bloc.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/address_service.dart';
import 'package:autonomy_flutter/service/domain_address_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

/// Onboarding page for adding a new view-only address.
///
/// This follows the interaction pattern of [ViewExistingAddress] but
/// uses the new onboarding shell visual language.

class OnboardingAddAddressInputPagePayload {
  OnboardingAddAddressInputPagePayload({
    this.isFromOnboarding = true,
  });

  final bool isFromOnboarding;
}

class OnboardingAddAddressInputPage extends StatefulWidget {
  const OnboardingAddAddressInputPage({
    super.key,
    required this.payload,
  });

  /// Whether this page is part of onboarding flow.
  /// When false, the back title will be different.

  final OnboardingAddAddressInputPagePayload payload;

  @override
  State<OnboardingAddAddressInputPage> createState() =>
      _OnboardingAddAddressInputPageState();
}

class _OnboardingAddAddressInputPageState
    extends State<OnboardingAddAddressInputPage> {
  final _controller = TextEditingController();

  late final OnboardingAddAddressBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = OnboardingAddAddressBloc(
      injector<DomainAddressService>(),
      injector<AddressService>(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: BlocConsumer<OnboardingAddAddressBloc, OnboardingAddAddressState>(
          bloc: _bloc,
          listener: (context, state) async {
            if (state is OnboardingAddAddressSuccessState) {
              // On success, return to the previous onboarding screen
              // and pass back the newly linked wallet address.
              Navigator.of(context).pop(state.walletAddress);
            }
          },
          builder: (context, state) {
            final isLoading = state.isSubmitting;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11.5),
              child: Column(
                children: [
                  const SizedBox(height: 218.52),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 21),
                    decoration: BoxDecoration(
                      color: AppColor.primaryBlack,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !isLoading,
                            style: theme.textTheme.body,
                            cursorColor: isLoading
                                ? AppColor.feralFileMediumGrey
                                : AppColor.white,
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Address or ENS / Tezos domain',
                              hintStyle: AppTypography.body(context).white,
                            ),
                            onSubmitted: state.isSubmitting
                                ? null
                                : (text) {
                                    _bloc.add(
                                      OnboardingAddConnectionEvent(
                                        text,
                                        widget.payload.isFromOnboarding,
                                      ),
                                    );
                                  },
                          ),
                        ),
                        if (state.isSubmitting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(AppColor.white),
                            ),
                          )
                        else
                          GestureDetector(
                            child: SvgPicture.asset(
                                'assets/images/Fullscreen.svg'),
                            onTap: () async {
                              final text = await injector<NavigationService>()
                                  .navigateTo(
                                AppRouter.scanQRPage,
                                arguments: const ScanQRPagePayload(
                                  scannerItem: ScannerItem.ETH_ADDRESS,
                                ),
                              );
                              if (text != null && text is String) {
                                _controller.text = text;
                                _bloc.add(OnboardingAddConnectionEvent(
                                  text,
                                  widget.payload.isFromOnboarding,
                                ));
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (context) {
                        if (state.error != null) {
                          return Text(
                            "We couldn't validate this address. Check it and try again.",
                            style: AppTypography.body(context).red,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}
