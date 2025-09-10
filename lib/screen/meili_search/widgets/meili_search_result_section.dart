//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/artwork_common_widget.dart';
import 'package:flutter/material.dart';

class MeiliSearchResultSection<T> extends StatelessWidget {
  const MeiliSearchResultSection({
    required this.title,
    required this.builder,
    super.key,
  });
  final String title;
  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    return SectionExpandedWidget(
      header: title,
      headerStyle: Theme.of(context).textTheme.ppMori700White16,
      isExpandedDefault: true,
      withDivider: false,
      headerPadding: const EdgeInsets.only(
        bottom: 16,
        left: 15,
        right: 15,
      ),
      child: builder(context),
    );
  }
}
