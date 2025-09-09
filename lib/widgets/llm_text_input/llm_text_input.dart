import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/view/record_controller.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/widgets/command-dot/command_dot.dart';
import 'package:autonomy_flutter/widgets/buttons/send_button.dart';
import 'package:flutter/material.dart';

class LLMTextInput extends StatefulWidget {
  const LLMTextInput({
    super.key,
    this.placeholder = MessageConstants.askAnythingText,
    this.onSend,
    this.onChanged,
    this.autoFocus = false,
    this.active = false,
    this.enabled = true,
    this.controller,
  });

  final String placeholder;
  final bool autoFocus;
  final bool active;
  final bool enabled;
  final void Function(String)? onSend;
  final void Function(String)? onChanged;
  final TextEditingController? controller;

  @override
  State<LLMTextInput> createState() => _LLMTextInputState();
}

class _LLMTextInputState extends State<LLMTextInput> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();

    if (widget.autoFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _textController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(LLMTextInputTokens.padding.toDouble()),
      child: Container(
        decoration: BoxDecoration(
          color: LLMTextInputTokens.llmBgColor,
          borderRadius: BorderRadius.circular(
            _focusNode.hasFocus
                ? LLMTextInputTokens.llmActiveCornerRadius.toDouble()
                : LLMTextInputTokens.llmCornerRadius.toDouble(),
          ),
        ),
        padding: widget.active
            ? EdgeInsets.all(LLMTextInputTokens.llmActivePadding.toDouble())
            : EdgeInsets.fromLTRB(
                LLMTextInputTokens.llmPaddingLeft.toDouble(),
                LLMTextInputTokens.llmPaddingVertical.toDouble(),
                LLMTextInputTokens.llmPaddingRight.toDouble(),
                LLMTextInputTokens.llmPaddingVertical.toDouble(),
              ),
        child: Row(
          children: [
            Expanded(
              child: widget.active
                  ? TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      style: Theme.of(context).textTheme.small,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.placeholder,
                        hintStyle: Theme.of(context).textTheme.small,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                          widget.onSend?.call(text);
                          _textController.clear();
                        }
                      },
                      onChanged: (text) {
                        widget.onChanged?.call(text);
                      },
                    )
                  : GestureDetector(
                      onTap: () {
                        injector<NavigationService>().popToRouteOrPush(
                          AppRouter.voiceCommandPage,
                          arguments: RecordControllerScreenPayload(
                            isListening: false,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          widget.placeholder,
                          style: Theme.of(context).textTheme.small,
                        ),
                      ),
                    ),
            ),
            if (widget.active) ...[
              SizedBox(width: LLMTextInputTokens.llmActiveGap.toDouble()),
              SendButton(
                onTap: () {
                  if (_textController.text.isNotEmpty) {
                    final text = _textController.text;
                    widget.onSend?.call(text);
                    _textController.clear();
                  }
                },
              ),
            ] else ...[
              CommandDot(
                onTap: () {
                  injector<NavigationService>().popToRouteOrPush(
                    AppRouter.voiceCommandPage,
                    arguments: RecordControllerScreenPayload(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
