//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/view/header.dart';
import 'package:flutter/material.dart';

class MeiliSearchResultSection<T> extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext context) builder;

  const MeiliSearchResultSection({
    super.key,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HeaderView(title: title),
        const SizedBox(height: 10),
        builder(context),
      ],
    );
  }
}
