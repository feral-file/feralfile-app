//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

class AuSecondaryButton extends StatelessWidget {
  final Function() onPressed;
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const AuSecondaryButton({
    required this.onPressed,
    required this.text,
    super.key,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 43,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: borderColor ?? Colors.white),
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .ppMori400White14
                .copyWith(color: textColor),
          ),
        ),
      );
}

class AuCustomButton extends StatelessWidget {
  final Function()? onPressed;
  final Widget? child;

  const AuCustomButton(
      {required this.onPressed, required this.child, super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 43,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColor.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            side: const BorderSide(),
            alignment: Alignment.center,
          ),
          onPressed: onPressed,
          child: child,
        ),
      );
}
