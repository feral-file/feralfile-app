//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class TagBlockSyntax extends md.BlockSyntax {
  static const String _pattern = r'^\[#\](.*)$';

  @override
  RegExp get pattern => RegExp(_pattern);

  TagBlockSyntax();

  @override
  md.Node parse(md.BlockParser parser) {
    var childLines = parseChildLines(parser);

    final contents = childLines.map((e) => e?.content).toList()
      ..removeWhere((element) => element == null);
    var content = contents.join('\n');

    final md.Element el = md.Element('p', [
      md.Element('#', [md.Text(content)]),
    ]);

    return el;
  }
}

class TagBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final parts =
        element.textContent.replaceFirst('[#]', '').trim().split(' - ');
    return Builder(
        builder: (context) => parts.length == 2
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(parts[1],
                      style: Theme.of(context).textTheme.ppMori400Grey14),
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColor.greyMedium,
                        ),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(64))),
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text(parts[0],
                        style: Theme.of(context).textTheme.ppMori400Grey12),
                  )
                ],
              )
            : Text(element.textContent, style: preferredStyle));
  }
}
