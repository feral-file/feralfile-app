//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/style.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

class ImportantNoteView extends StatelessWidget {
  final String note;
  final String? title;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? noteStyle;
  final Color? borderColor;

  const ImportantNoteView({
    required this.note,
    super.key,
    this.title,
    this.backgroundColor,
    this.titleStyle,
    this.noteStyle,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColor.feralFileHighlight,
        border: Border.all(
          color: borderColor ?? backgroundColor ?? AppColor.feralFileHighlight,
          width: 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            title ?? 'important'.tr(),
            style: titleStyle ?? theme.textTheme.ppMori700Black14,
          ),
          const SizedBox(height: 15),
          HtmlWidget(
            note,
            textStyle: noteStyle ?? theme.textTheme.ppMori400White14,
            customStylesBuilder: auHtmlStyle,
            onTapUrl: (url) async {
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
              return true;
            },
          ),
        ],
      ),
    );
  }
}
