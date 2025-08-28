//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2022 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:auto_size_text/auto_size_text.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/string_ext.dart';
import 'package:flutter/material.dart';

class PagingBar extends StatelessWidget {
  final Function(String value) onTap;
  final Function() onDragging;
  final Function() onDragEnd;
  final String? selectedCharacter;

  const PagingBar(
      {required this.onTap,
      required this.onDragging,
      required this.onDragEnd,
      this.selectedCharacter,
      super.key});

  static const _height = 30.0;
  static const _sensitivity = 5;
  static const _dragAreaRatio = 4.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width - 30;
    final int characterWidth = (width / listCharacters.length).floor() - 2;
    final theme = Theme.of(context);
    final index = selectedCharacter == null
        ? 0
        : listCharacters.indexOf(selectedCharacter ?? listCharacters.first);
    final delta = width / listCharacters.length;
    final dragWidth = characterWidth * _dragAreaRatio;
    final double dx = delta * index - characterWidth * (_dragAreaRatio - 1) / 2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: width,
        height: _height,
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: listCharacters
                    .map((e) => GestureDetector(
                          onTap: () => onTap(e),
                          child: SizedBox(
                            width: characterWidth.toDouble(),
                            child: AutoSizeText(
                              e,
                              style: theme.textTheme.ppMori400Grey14.copyWith(
                                  color: e == selectedCharacter
                                      ? AppColor.white
                                      : AppColor.auQuickSilver),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Positioned(
              left: dx,
              child: Draggable(
                axis: Axis.horizontal,
                feedback: Material(
                  color: Colors.transparent,
                  child: _dragWidget(dragWidth),
                ),
                childWhenDragging: _dragWidget(dragWidth),
                onDragEnd: (details) {
                  onDragEnd();
                },
                onDragUpdate: (details) {
                  onDragging();

                  final index = (details.localPosition.dx / delta).floor();
                  if (index >= 0 && index < listCharacters.length) {
                    if (details.localPosition.dx - delta * index >
                        _sensitivity) {
                      return;
                    }
                    if (selectedCharacter != listCharacters[index]) {
                      onTap(listCharacters[index]);
                    }
                  }
                },
                child: _dragWidget(dragWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dragWidget(double width) => Container(
        width: width,
        height: _height,
        color: Colors.transparent,
      );
}
