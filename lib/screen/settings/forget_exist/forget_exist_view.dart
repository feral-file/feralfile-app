//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_bloc.dart';
import 'package:autonomy_flutter/screen/settings/forget_exist/forget_exist_state.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/color_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roundcheckbox/roundcheckbox.dart';

class ForgetExistView extends StatelessWidget {
  const ForgetExistView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<ForgetExistBloc, ForgetExistState>(
        listener: (context, state) async {
          if (state.isProcessing == false) {
            await Navigator.of(context).pushNamedAndRemoveUntil(
                AppRouter.onboardingPage, (_) => false);
          }
        },
        builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'This will permanently:',
                      style: theme.textTheme.ppMori700White14,
                    )
                  ],
                ),
                const SizedBox(
                  height: 12,
                ),
                Row(
                  children: [
                    Container(
                      width: 24,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: dotIcon(color: AppColor.white, size: 6),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: RichText(
                                  maxLines: 3,
                                  textScaler: MediaQuery.textScalerOf(context),
                                  text: TextSpan(
                                    style:
                                        theme.primaryTextTheme.ppMori400White14,
                                    children: <TextSpan>[
                                      TextSpan(
                                        text:
                                            'Remove your art addresses (view-only) and all app data on this device.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: dotIcon(color: AppColor.white, size: 6),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: Text(
                                  'Unpair this device from any FF1 you’ve connected.',
                                  style:
                                      theme.primaryTextTheme.ppMori400White14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: dotIcon(color: AppColor.white, size: 6),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Delete your playlists from Feral File and stop sharing them:',
                                      style: theme
                                          .primaryTextTheme.ppMori400White14,
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 24,
                                        ),
                                        Text(
                                          'o ',
                                          style: theme.primaryTextTheme
                                              .ppMori400White12,
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Others may briefly see cached copies; they won’t update and will disappear after refresh.',
                                            style: theme
                                                .textTheme.ppMori400White14,
                                          ),
                                        )
                                      ],
                                    ),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          width: 24,
                                        ),
                                        Text(
                                          'o ',
                                          style: theme.primaryTextTheme
                                              .ppMori400White12,
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'If someone republished one of your playlists under their own feed, that copy will continue under their control (not yours).',
                                            style: theme
                                                .textTheme.ppMori400White14,
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(
                  height: 16,
                ),
                Text(
                  'Once you continue, we can’t recover this data.',
                  style: theme.textTheme.ppMori700White14,
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: () => context
                      .read<ForgetExistBloc>()
                      .add(UpdateCheckEvent(!state.isChecked)),
                  child: Row(
                    children: [
                      RoundCheckBox(
                        size: 24,
                        borderColor: theme.colorScheme.secondary,
                        uncheckedColor: theme.colorScheme.primary,
                        checkedColor: theme.colorScheme.secondary,
                        isChecked: state.isChecked,
                        checkedWidget: Icon(
                          CupertinoIcons.checkmark,
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                        onTap: (bool? value) {
                          context
                              .read<ForgetExistBloc>()
                              .add(UpdateCheckEvent(value ?? false));
                        },
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                          child: Text(
                        'i_understand'.tr(),
                        //"I understand that this action cannot be undone.",
                        style: theme.primaryTextTheme.ppMori400White12,
                      )),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 40,
                ),
                PrimaryButton(
                  text: state.isProcessing == true
                      ? 'Deleting'.tr()
                      : 'Delete my information '.tr(),
                  color: state.isProcessing == null && state.isChecked
                      ? null
                      : theme.disableColor,
                  onTap: state.isProcessing == null && state.isChecked
                      ? () {
                          context
                              .read<ForgetExistBloc>()
                              .add(ConfirmForgetExistEvent());
                        }
                      : null,
                  isProcessing: state.isProcessing == true,
                ),
                const SizedBox(
                  height: 10,
                ),
                OutlineButton(
                  onTap: () => Navigator.pop(context),
                  text: 'cancel_dialog'.tr(),
                ),
              ],
            ));
  }
}
