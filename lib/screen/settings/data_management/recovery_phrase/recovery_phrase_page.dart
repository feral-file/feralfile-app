//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';
import 'dart:io';

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/github_doc.dart';
import 'package:autonomy_flutter/service/channel_service.dart';
import 'package:autonomy_flutter/service/local_auth_service.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/service/versions_service.dart';
import 'package:autonomy_flutter/util/secure_screen_channel.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/primary_button.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:feralfile_app_theme/feral_file_app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class RecoveryPhrasePage extends StatefulWidget {
  const RecoveryPhrasePage({super.key});

  @override
  State<RecoveryPhrasePage> createState() => _RecoveryPhrasePageState();
}

class _RecoveryPhrasePageState extends State<RecoveryPhrasePage> {
  bool _isShow = false;
  final Map<String, List<String>> _mapSeed = {};
  bool? _isBackUpAvailable;

  @override
  void initState() {
    super.initState();
    SecureScreenChannel.setSecureFlag(true);
    WidgetsBinding.instance.addPostFrameCallback((context) {
      unawaited(_loadRecoveryPhrase());
    });
  }

  @override
  void dispose() {
    SecureScreenChannel.setSecureFlag(false);
    super.dispose();
  }

  Future<void> _loadRecoveryPhrase() async {
    final map = await ChannelService().exportMnemonicForAllPersonaUUIDs();
    setState(() {
      _mapSeed.addAll(map);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: getBackAppBar(
          context,
          title: 'your_recovery_phrase'.tr(),
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
        body: _body(context, _mapSeed),
      );

  Widget _seedItem(BuildContext context,
      {required List<String> words, String? passphrase}) {
    if (words.isEmpty) {
      return const SizedBox();
    }
    final theme = Theme.of(context);
    final roundNumber = words.length ~/ 2 + words.length % 2;
    return Container(
      margin: ResponsiveLayout.pageHorizontalEdgeInsetsWithSubmitButton,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _getBackUpState(context),
              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Table(
                        children: List.generate(
                          roundNumber,
                          (index) =>
                              _tableRow(context, index, roundNumber, words),
                        ),
                        border: TableBorder.all(
                            color: AppColor.auLightGrey,
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      if (passphrase != null && passphrase.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColor.auLightGrey),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: RichText(
                            textScaler: MediaQuery.textScalerOf(context),
                            text: TextSpan(
                              children: <TextSpan>[
                                TextSpan(
                                  text: 'passphrase'.tr(),
                                  style:
                                      theme.textTheme.ppMori400FFQuickSilver14,
                                ),
                                const TextSpan(text: '  '),
                                TextSpan(
                                    text: passphrase,
                                    style: theme.textTheme.ppMori400Black14
                                        .copyWith(
                                            color: _isShow
                                                ? AppColor.primaryBlack
                                                : AppColor.white)),
                              ],
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                  if (!_isShow)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColor.white.withOpacity(0.6),
                        ),
                        child: Center(
                            child: ConstrainedBox(
                          constraints: const BoxConstraints.tightFor(
                              width: 168, height: 45),
                          child: _revealButton(context),
                        )),
                      ),
                    ),
                ],
              ),
              _recommend(context),
              const SizedBox(height: 30),
            ],
          ),
          _settingButton(context)
        ],
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, List<String>> mapSeed) {
    final seedList = mapSeed.entries.toList();
    return ListView.builder(
      itemCount: seedList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _importantNoteView(context),
          );
        }
        final entry = seedList[index - 1];
        final value = entry.value;
        final passphrase = value.first;
        final words = value.sublist(1);
        return _seedItem(context, words: words, passphrase: passphrase);
      },
    );
  }

  Widget _importantNoteView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.feralFileHighlight,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('important_update'.tr(),
                style: Theme.of(context).textTheme.ppMori700Black16),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.ppMori400Black14,
                children: [
                  TextSpan(
                    text: '${'get_recovery_phrase_desc'.tr()} ',
                  ),
                  TextSpan(
                    text: 'read_more'.tr(),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        injector<VersionService>().showReleaseNotes();
                      },
                    style: const TextStyle(
                      color: AppColor.primaryBlack,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _revealButton(BuildContext context) => PrimaryButton(
        text: 'tap_to_reveal'.tr(),
        onTap: () async {
          final didAuthenticate =
              await LocalAuthenticationService.checkLocalAuth();

          if (!didAuthenticate) {
            return;
          }
          setState(() {
            _isShow = !_isShow;
          });
          Future.delayed(
            const Duration(seconds: 60),
            () {
              if (mounted) {
                setState(() {
                  _isShow = !_isShow;
                });
              }
            },
          );
        },
      );

  Widget _rowItem(BuildContext context, int index, List<String> words) {
    final theme = Theme.of(context);
    final isNull = index >= words.length;
    final word = isNull ? '' : words[index];
    NumberFormat formatter = NumberFormat('00');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            alignment: Alignment.centerRight,
            child: Text(isNull ? '' : formatter.format(index + 1),
                style: theme.textTheme.ppMori400Grey14),
          ),
          const SizedBox(width: 16),
          Text(word,
              style: theme.textTheme.ppMori400Black14.copyWith(
                  color: _isShow ? AppColor.primaryBlack : AppColor.white)),
        ],
      ),
    );
  }

  Widget _getBackUpState(BuildContext context) {
    final theme = Theme.of(context);
    final commonStyle = theme.textTheme.ppMori400Black14;
    final customLinkStyle = commonStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: AppColor.primaryBlack,
    );
    final iCloudKeychain = TextSpan(
      text: 'icloud_keychain'.tr(),
      style: customLinkStyle,
      recognizer: TapGestureRecognizer()
        ..onTap = () =>
            unawaited(Navigator.of(context).pushNamed(AppRouter.githubDocPage,
                arguments: GithubDocPayload(
                  title: 'ff_app_security'.tr(),
                  prefix: GithubDocPage.ffDocsAppsPrefix,
                  document: '/security/ios',
                  fileNameAsLanguage: true,
                ))),
    );

    final androidBlockStore = TextSpan(
      text: 'android_block_store'.tr(),
      style: customLinkStyle,
      recognizer: TapGestureRecognizer()
        ..onTap = () =>
            unawaited(Navigator.of(context).pushNamed(AppRouter.githubDocPage,
                arguments: GithubDocPayload(
                  title: 'ff_app_security'.tr(),
                  prefix: GithubDocPage.ffDocsAppsPrefix,
                  document: '/security/android',
                  fileNameAsLanguage: true,
                ))),
    );

    if (_isBackUpAvailable == null) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SRP_is_crucial'.tr(),
          style: commonStyle,
        ),
        const SizedBox(height: 12),
        Text(
          'as_a_non_custodial_wallet'.tr(),
          style: commonStyle,
        ),
        const SizedBox(height: 12),
        Text('remember_if_you_lose_your_SRP'.tr(),
            style: theme.textTheme.ppMori700Black14),
        const SizedBox(height: 12),
        if (_isBackUpAvailable == true) ...[
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: theme.textTheme.ppMori400Black14,
              children: <TextSpan>[
                TextSpan(
                  text: '${'yrp_we’ve_safely'.tr()} ',
                ),
                if (Platform.isIOS) iCloudKeychain else androidBlockStore,
                TextSpan(
                  text: 'yrp_you_may_also'.tr(),
                ),
              ],
            ),
          ),
        ] else ...[
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: theme.textTheme.ppMori400Black14,
              children: [
                if (Platform.isIOS) iCloudKeychain else androidBlockStore,
                TextSpan(
                  text: '${'_is_'.tr()} ',
                ),
                TextSpan(
                  text: 'turned_off'.tr().toLowerCase(),
                  style: theme.textTheme.ppMori700Black14,
                ),
                TextSpan(
                  text: ' ${'unable_backup'.tr()}',
                  style: theme.textTheme.ppMori400Black14,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _recommend(BuildContext context) {
    final theme = Theme.of(context);
    if (_isBackUpAvailable != false) {
      return const SizedBox();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(
            Platform.isAndroid
                ? 'recommend_google_cloud'.tr()
                : 'recommend_icloud_key'.tr(),
            style: theme.textTheme.ppMori700Black14),
      ],
    );
  }

  Widget _settingButton(BuildContext context) {
    if (_isBackUpAvailable != false) {
      return const SizedBox();
    }
    return Row(
      children: [
        Expanded(
          child: Platform.isAndroid
              ? OutlineButton(
                  text: 'open_device_setting'.tr(),
                  onTap: () => unawaited(
                      injector<NavigationService>().openAccountSettings()),
                  color: AppColor.white,
                  borderColor: AppColor.primaryBlack,
                  textColor: AppColor.primaryBlack,
                )
              : OutlineButton(
                  onTap: () => unawaited(openAppSettings()),
                  text: 'open_icloud_setting'.tr(),
                  color: AppColor.white,
                  borderColor: AppColor.primaryBlack,
                  textColor: AppColor.primaryBlack,
                ),
        ),
      ],
    );
  }

  TableRow _tableRow(BuildContext context, int index, int itemsEachCol,
          List<String> words) =>
      TableRow(children: [
        _rowItem(context, index, words),
        _rowItem(context, index + itemsEachCol, words),
      ]);
}
