import 'package:autonomy_flutter/design/build/components/CommandDot.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/design/build/components/NowPlayingBar.dart';
import 'package:autonomy_flutter/main.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:flutter/material.dart';

class BottomSpacing extends StatelessWidget {
  const BottomSpacing({super.key});

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const llmInputHeight = LLMTextInputTokens.padding * 2 +
        LLMTextInputTokens.llmPaddingVertical * 2 +
        CommandDotTokens.size;

    return ValueListenableBuilder(
      valueListenable: nowDisplayingShowing,
      builder: (context, value, child) {
        return Container(
          height: paddingBottom +
              (value
                  ? (UIConstants.nowDisplayingBarBottomPadding +
                      NowPlayingBarTokens.collapseHeight)
                  : 0) +
              llmInputHeight,
        );
      },
    );
  }
}
