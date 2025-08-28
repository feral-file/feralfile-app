//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/tag_markdown.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReleaseNotesPage extends StatefulWidget {
  final String releaseNotes;

  const ReleaseNotesPage({required this.releaseNotes, super.key});

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  @override
  void dispose() {
    super.dispose();
    UIHelper.currentDialogTitle = '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: 'release_notes'.tr(),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Container(
        color: theme.colorScheme.background,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    Text(
                      'believe_transparency'.tr(),
                      style: theme.textTheme.ppMori700Black16,
                    ),
                    Row(
                      children: [
                        Text(
                          '${'autonomy_is_'.tr()} ',
                          style: theme.textTheme.ppMori400Black16,
                        ),
                        GestureDetector(
                          child: Text(
                            'open_source'.tr(),
                            style: theme.textTheme.ppMori400Black16.copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: AppColor.primaryBlack,
                            ),
                          ),
                          onTap: () async => launchUrl(
                              Uri.parse(AUTONOMY_CLIENT_GITHUB_LINK),
                              mode: LaunchMode.externalApplication),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Divider(
                      color: AppColor.feralFileHighlight,
                      thickness: 1,
                    ),
                    Markdown(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      data: widget.releaseNotes,
                      softLineBreak: true,
                      selectable: true,
                      padding: const EdgeInsets.only(bottom: 32, top: 32),
                      styleSheet: markDownChangeLogStyle(context),
                      builders: <String, MarkdownElementBuilder>{
                        '#': TagBuilder(),
                      },
                      blockSyntaxes: [
                        TagBlockSyntax(),
                      ],
                      onTapLink: (text, href, title) async {
                        if (href == null) {
                          return;
                        }
                        if (DEEP_LINKS
                            .any((prefix) => href.startsWith(prefix))) {
                          injector<DeeplinkService>().handleDeeplink(href);
                        } else if (await canLaunchUrlString(href)) {
                          await launchUrlString(href,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
