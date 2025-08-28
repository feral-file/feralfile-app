import 'dart:async';

import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_svg/flutter_svg.dart';

class CustomChatInputWidget extends StatefulWidget {
  final FutureOr<void> Function(types.PartialText message) onSendPressed;
  final TextEditingController textEditingController;
  final bool isProcessing; // Add this line

  const CustomChatInputWidget({
    super.key,
    required this.onSendPressed,
    required this.textEditingController,
    this.isProcessing = false, // Initialize with false
  });

  @override
  State<CustomChatInputWidget> createState() => _CustomChatInputWidgetState();
}

class _CustomChatInputWidgetState extends State<CustomChatInputWidget> {
  String _sendIcon = 'assets/images/sendMessage.svg';

  @override
  void initState() {
    super.initState();
    widget.textEditingController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.textEditingController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (_sendIcon == 'assets/images/sendMessageFilled.svg' &&
            widget.textEditingController.text.trim() == '' ||
        _sendIcon == 'assets/images/sendMessage.svg' &&
            widget.textEditingController.text.trim() != '') {
      setState(() {
        _sendIcon = widget.textEditingController.text.trim() != ''
            ? 'assets/images/sendMessageFilled.svg'
            : 'assets/images/sendMessage.svg';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        border: Border.all(
            color: widget.isProcessing
                ? AppColor.auQuickSilver
                : AppColor.auLightGrey),
        borderRadius: BorderRadius.circular(10),
        color: AppColor.auGreyBackground, // Keep background color normal
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.textEditingController,
              // enabled: !widget.isProcessing, // Remove this line to enable input
              decoration: InputDecoration(
                hintText: 'Ask me to display art',
                hintStyle: theme.textTheme.ppMori400White12.copyWith(
                    color: AppColor.auQuickSilver), // Keep hint color normal
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: theme.textTheme.ppMori400White12,
              cursorColor: theme.colorScheme.secondary,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.send,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty && !widget.isProcessing) {
                  widget.onSendPressed(types.PartialText(text: text));
                  FocusScope.of(context).unfocus();
                } else if (widget.isProcessing) {
                  // If processing, just hide the keyboard without sending
                  FocusScope.of(context).unfocus();
                }
              },
            ),
          ),
          IconButton(
            icon: SvgPicture.asset(
              _sendIcon,
              colorFilter: ColorFilter.mode(
                  widget.isProcessing
                      ? AppColor.auQuickSilver
                          .withOpacity(0.5) // Dim icon when disabled
                      : AppColor.white,
                  BlendMode.srcIn),
            ),
            onPressed: widget.isProcessing // Disable button when processing
                ? null
                : () {
                    if (widget.textEditingController.text.trim().isNotEmpty) {
                      widget.onSendPressed(types.PartialText(
                          text: widget.textEditingController.text));
                      FocusScope.of(context).unfocus();
                    }
                  },
          ),
        ],
      ),
    );
  }
}
