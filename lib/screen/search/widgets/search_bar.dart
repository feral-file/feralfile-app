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

class SearchBar extends StatefulWidget {
  const SearchBar({
    required this.controller,
    required this.onSubmitted,
    super.key,
    this.hintText,
    this.autoFocus = false,
  });

  final TextEditingController controller;
  final void Function(String) onSubmitted;
  final String? hintText;
  final bool autoFocus;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColor.auGrey,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      padding: EdgeInsets.all(LayoutConstants.space2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              style: AppTypography.body(context).white,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Search',
                hintStyle: AppTypography.body(context).copyWith(
                  color: AppColor.auGrey,
                ),
                //boder radius 10
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(LayoutConstants.space2),
                isDense: true,
              ),
              onSubmitted: (value) {
                widget.onSubmitted(value);
              },
            ),
          ),
          SizedBox(width: LayoutConstants.space5),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.unfocus();
              widget.onSubmitted(widget.controller.text);
            },
            child: SizedBox(
              width: LayoutConstants.minTouchTarget,
              height: LayoutConstants.minTouchTarget,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/search.svg',
                  width: LayoutConstants.iconSizeMedium,
                  height: LayoutConstants.iconSizeMedium,
                  colorFilter: const ColorFilter.mode(
                    AppColor.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
