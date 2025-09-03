import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/design/build/typography.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/command_dot.dart';
import 'package:flutter/material.dart';

class LLMTextInput extends StatelessWidget {
  const LLMTextInput({super.key, this.placeholder = 'Ask anything'});

  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        LLMTextInputTokens.llmTextInputPadding.toDouble(),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: LLMTextInputTokens.llmTextInputLlmBgColor,
          borderRadius: BorderRadius.circular(
            LLMTextInputTokens.llmTextInputLlmCornerRadius.toDouble(),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          LLMTextInputTokens.llmTextInputLlmPaddingLeft.toDouble(),
          LLMTextInputTokens.llmTextInputLlmPaddingVertical.toDouble(),
          LLMTextInputTokens.llmTextInputLlmPaddingRight.toDouble(),
          LLMTextInputTokens.llmTextInputLlmPaddingVertical.toDouble(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              placeholder,
              style: TextStyle(
                color: LLMTextInputTokens.llmTextInputLlmTextColor,
                fontFamily: TypographyTokens.smallFontFamily,
                fontSize: TypographyTokens.smallFontSize.toDouble(),
                fontWeight: FontWeight.w400,
                height: TypographyTokens.smallLineHeight /
                    TypographyTokens.smallFontSize,
                letterSpacing: TypographyTokens.smallLetterSpacing.toDouble(),
              ),
            ),
            const CommandDot(),
          ],
        ),
      ),
    );
  }
}
