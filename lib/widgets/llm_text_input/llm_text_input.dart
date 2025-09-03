import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/design/build/typography.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/command_dot.dart';
import 'package:flutter/material.dart';

class LLMTextInput extends StatelessWidget {
  const LLMTextInput({super.key, this.placeholder = 'Ask anything'});

  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        LLMTextInputTokens.padding.toDouble(),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: LLMTextInputTokens.llmBgColor,
          borderRadius: BorderRadius.circular(
            LLMTextInputTokens.llmCornerRadius.toDouble(),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          LLMTextInputTokens.llmPaddingLeft.toDouble(),
          LLMTextInputTokens.llmPaddingVertical.toDouble(),
          LLMTextInputTokens.llmPaddingRight.toDouble(),
          LLMTextInputTokens.llmPaddingVertical.toDouble(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              placeholder,
              style: TextStyle(
                color: LLMTextInputTokens.llmTextColor,
                fontFamily: TypographyTokens.smallFontFamily,
                fontSize: TypographyTokens.smallFontSize.toDouble(),
                fontWeight: FontWeight.w400,
                height: TypographyTokens.smallLineHeight /
                    TypographyTokens.smallFontSize,
                letterSpacing: TypographyTokens.smallLetterSpacing.toDouble(),
              ),
            ),
            GestureDetector(
              onTap: () {
                injector<NavigationService>().popToRouteOrPush(
                  AppRouter.voiceCommandPage,
                );
              },
              child: const CommandDot(),
            ),
          ],
        ),
      ),
    );
  }
}
