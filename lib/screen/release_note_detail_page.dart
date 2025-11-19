//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/model/release_note.dart';
import 'package:autonomy_flutter/service/deeplink_service.dart';
import 'package:autonomy_flutter/util/constants.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:autonomy_flutter/util/ui_helper.dart';
import 'package:autonomy_flutter/view/back_appbar.dart';
import 'package:autonomy_flutter/view/tag_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReleaseNoteDetailPage extends StatefulWidget {
  const ReleaseNoteDetailPage({required this.releaseNote, super.key});

  final ReleaseNote releaseNote;

  @override
  State<ReleaseNoteDetailPage> createState() => _ReleaseNoteDetailPageState();
}

class _ReleaseNoteDetailPageState extends State<ReleaseNoteDetailPage> {
  @override
  void dispose() {
    super.dispose();
    UIHelper.currentDialogTitle = '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getBackAppBar(
        context,
        title: widget.releaseNote.date,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Markdown(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    data: widget.releaseNote.content,
                    softLineBreak: true,
                    selectable: true,
                    padding: const EdgeInsets.all(24),
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
                      if (DEEP_LINKS.any((prefix) => href.startsWith(prefix))) {
                        injector<DeeplinkService>().handleDeeplink(href);
                      } else if (await canLaunchUrlString(href)) {
                        await launchUrlString(
                          href,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
