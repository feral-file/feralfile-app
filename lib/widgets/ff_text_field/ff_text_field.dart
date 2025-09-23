import 'package:autonomy_flutter/common/injector.dart';
import 'package:autonomy_flutter/design/build/components/LLMTextInput.dart';
import 'package:autonomy_flutter/design/build/components/SendButton.dart';
import 'package:autonomy_flutter/screen/app_router.dart';
import 'package:autonomy_flutter/screen/mobile_controller/constants/ui_constants.dart';
import 'package:autonomy_flutter/screen/mobile_controller/screens/explore/view/record_controller.dart';
import 'package:autonomy_flutter/screen/scan_qr/scan_qr_page.dart';
import 'package:autonomy_flutter/service/navigation_service.dart';
import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/au_icons.dart';
import 'package:autonomy_flutter/widgets/llm_text_input/send_button.dart';
import 'package:flutter/material.dart';

class FFTextField extends StatefulWidget {
  const FFTextField({
    super.key,
    this.placeholder = MessageConstants.askAnythingText,
    this.onSend,
    this.onChanged,
    this.autoFocus = false,
    this.active = false,
    this.enabled = true,
    this.controller,
    this.isError = false,
    this.isLoading = false,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType = TextInputType.text,
  });

  final String placeholder;
  final bool autoFocus;
  final bool active;
  final bool enabled;
  final bool isError;
  final bool isLoading;
  final void Function(String)? onSend;
  final void Function(String)? onChanged;
  final TextEditingController? controller;
  final int maxLines;
  final int minLines;
  final TextInputType keyboardType;
  @override
  State<FFTextField> createState() => _FFTextFieldState();
}

class _FFTextFieldState extends State<FFTextField> {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: LLMTextInputTokens.llmBgColor,
              borderRadius: BorderRadius.circular(
                LLMTextInputTokens.llmActiveCornerRadius.toDouble(),
              ),
              border: Border.all(
                color: widget.isError ? AppColor.red : Colors.transparent,
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
                          keyboardType: widget.keyboardType,
                          enabled: widget.enabled && !widget.isLoading,
                          style: Theme.of(context).textTheme.small.copyWith(
                                color: widget.isError ? AppColor.red : null,
                              ),
                          minLines: widget.minLines,
                          maxLines: widget.maxLines,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: widget.placeholder,
                            hintStyle:
                                Theme.of(context).textTheme.small.copyWith(
                                      color: widget.isError
                                          ? AppColor.red.withOpacity(0.7)
                                          : null,
                                    ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (text) {
                            if (text.isNotEmpty && !widget.isLoading) {
                              widget.onSend?.call(text);
                              _textController.clear();
                            }
                          },
                          onChanged: (text) {
                            if (!widget.isLoading) {
                              widget.onChanged?.call(text);
                            }
                          },
                        )
                      : GestureDetector(
                          onTap: () {
                            if (!widget.isLoading) {
                              injector<NavigationService>().popToRouteOrPush(
                                AppRouter.voiceCommandPage,
                                arguments: RecordControllerScreenPayload(
                                  isListening: false,
                                ),
                              );
                            }
                          },
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              widget.placeholder,
                              style: Theme.of(context).textTheme.small.copyWith(
                                    color: widget.isError ? AppColor.red : null,
                                  ),
                            ),
                          ),
                        ),
                ),
                if (widget.active &&
                        !widget.isError &&
                        _textController.text.isNotEmpty ||
                    widget.isLoading)
                  Row(
                    children: [
                      SizedBox(
                          width: LLMTextInputTokens.llmActiveGap.toDouble()),
                      _buildActionButton(),
                    ],
                  )
                else
                  GestureDetector(
                    child: Icon(
                      AuIcon.scan,
                      color: AppColor.white,
                      size: SendButtonTokens.size.toDouble(),
                    ),
                    onTap: () async {
                      dynamic res = await Navigator.of(context).pushNamed(
                        AppRouter.scanQRPage,
                        arguments: const ScanQRPagePayload(
                          scannerItem: ScannerItem.ETH_ADDRESS,
                        ),
                      );
                      final address = res as String?;
                      if (address == null) return;
                      setState(() {
                        _textController
                          ..clear()
                          ..text = address;
                        widget.onChanged?.call(_textController.text);
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (widget.isLoading) {
      return _buildLoadingIndicator();
    }

    return SendButton(
      onTap: () {
        if (_textController.text.isNotEmpty && !widget.isLoading) {
          final text = _textController.text;
          widget.onSend?.call(text);
          _textController.clear();
        }
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(4),
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppColor.white),
      ),
    );
  }
}
