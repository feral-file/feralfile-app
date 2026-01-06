//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/design/app_typography.dart';
import 'package:autonomy_flutter/design/layout_constants.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SearchBar extends StatelessWidget {
  const SearchBar({
    required this.controller,
    required this.onSubmitted,
    super.key,
    this.hintText,
  });

  final TextEditingController controller;
  final void Function(String) onSubmitted;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF4A4A4A),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(LayoutConstants.space5),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.body(context).white,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText ?? '|Search',
                hintStyle: AppTypography.body(context).copyWith(
                  color: const Color(0xFFB7B7B7),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: onSubmitted,
            ),
          ),
          SizedBox(width: LayoutConstants.space5),
          SvgPicture.asset(
            'assets/images/search.svg',
            width: LayoutConstants.iconSizeMedium,
            height: LayoutConstants.iconSizeMedium,
            colorFilter: const ColorFilter.mode(
              AppColor.white,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}
