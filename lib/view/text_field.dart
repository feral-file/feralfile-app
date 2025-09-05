import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:flutter/material.dart';

class TextFieldWidget extends StatefulWidget {
  final String? labelText;
  final TextStyle? style;
  final String? hintText;
  final TextStyle? hintStyle;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final InputBorder? enabledBorder;
  final Color? cursorColor;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final Function(String)? onFieldSubmitted;
  final Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextAlign textAlign;

  const TextFieldWidget({
    super.key,
    this.labelText,
    this.style,
    this.hintText,
    this.border,
    this.focusedBorder,
    this.enabledBorder,
    this.hintStyle,
    this.cursorColor,
    this.controller,
    this.validator,
    this.onFieldSubmitted,
    this.focusNode,
    this.onChanged,
    this.textAlign = TextAlign.start,
  });

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Visibility(
          visible: widget.labelText?.isNotEmpty ?? false,
          child: Text(
            widget.labelText ?? '',
            style: theme.textTheme.atlasWhiteBold12,
          ),
        ),
        TextFormField(
          focusNode: widget.focusNode,
          controller: widget.controller,
          style: widget.style,
          validator: widget.validator,
          textAlign: widget.textAlign,
          cursorColor: widget.cursorColor,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: widget.hintStyle,
            border: widget.border,
            focusedBorder: widget.focusedBorder,
            enabledBorder: widget.enabledBorder,
          ),
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
