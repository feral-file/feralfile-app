//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/responsive.dart';
import 'package:flutter/material.dart';

class AuTextField extends StatelessWidget {
  final String title;
  final String? labelSemantics;
  final String placeholder;
  final bool isError;
  final TextEditingController controller;
  final Widget? subTitleView;
  final Widget? suffix;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmit;
  final int? maxLines;
  final int? hintMaxLines;
  final FocusNode? focusNode;
  final bool isDark;
  final bool widePadding;
  final bool obscureText;
  final bool enableSuggestions;

  const AuTextField({
    required this.title,
    required this.controller,
    super.key,
    this.placeholder = '',
    this.isError = false,
    this.maxLines = 1,
    this.hintMaxLines,
    this.subTitleView,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmit,
    this.labelSemantics,
    this.focusNode,
    this.isDark = false,
    this.widePadding = false,
    this.obscureText = false,
    this.enableSuggestions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = controller.text.isEmpty;
    return Semantics(
      label: labelSemantics,
      child: Container(
          padding: (title.isNotEmpty || suffix != null) && !widePadding
              ? const EdgeInsets.only(top: 3, left: 8, bottom: 3)
              : const EdgeInsets.only(top: 13.5, left: 8, bottom: 16.5),
          decoration: BoxDecoration(
            border: Border.all(
                color: isEmpty
                    ? isDark
                        ? AppColor.auQuickSilver
                        : AppColor.auLightGrey
                    : isError
                        ? AppColor.red
                        : isDark
                            ? AppColor.white
                            : theme.colorScheme.primary),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (title.isNotEmpty) ...[
                          Text(
                            title,
                            style: ResponsiveLayout.isMobile
                                ? theme.textTheme.atlasGreyBold12
                                : theme.textTheme.atlasGreyBold14,
                          ),
                        ],
                        if (subTitleView != null)
                          Text(
                            ' | ',
                            style: ResponsiveLayout.isMobile
                                ? theme.textTheme.atlasGreyNormal12
                                : theme.textTheme.atlasGreyNormal14,
                          )
                        else
                          const SizedBox(),
                        subTitleView ?? const SizedBox(),
                      ],
                    ),
                    if (maxLines == 1) ...[
                      _textFieldWidget(context)
                    ] else ...[
                      Expanded(
                        child: _textFieldWidget(context),
                      ),
                    ]
                  ],
                ),
              ),
              suffix ?? const SizedBox(),
            ],
          )),
    );
  }

  Widget _textFieldWidget(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        autocorrect: false,
        focusNode: focusNode,
        maxLines: maxLines,
        obscureText: obscureText,
        enableSuggestions: enableSuggestions,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(0, 3, 0, 0),
          isDense: true,
          border: InputBorder.none,
          hintText: placeholder,
          hintMaxLines: hintMaxLines,
          hintStyle: ResponsiveLayout.isMobile
              ? theme.textTheme.ppMori400Black14
                  .copyWith(color: AppColor.auQuickSilver)
              : theme.textTheme.ppMori400Black16
                  .copyWith(color: AppColor.auQuickSilver, fontSize: 20),
        ),
        keyboardType: keyboardType,
        style: theme.textTheme.ppMori400Black14.copyWith(
            color: isError
                ? AppColor.red
                : isDark
                    ? AppColor.white
                    : null),
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmit ?? onChanged,
      ),
    );
  }
}
