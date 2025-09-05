import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/view/text_field.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class FFTextName extends StatefulWidget {
  final Function(String)? onSubmit;
  final FocusNode? focusNode;

  const FFTextName({
    required this.title,
    super.key,
    this.onSubmit,
    this.focusNode,
  });

  final String title;

  @override
  State<FFTextName> createState() => _FFTextNameState();
}

class _FFTextNameState extends State<FFTextName> {
  final _playlistNameC = TextEditingController();

  late FocusNode _focusNode;

  @override
  void initState() {
    _playlistNameC.text = widget.title;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(listener);
    super.initState();
  }

  // on update widget
  @override
  void didUpdateWidget(covariant FFTextName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      _playlistNameC.text = widget.title;
    }
  }

  void listener() {
    if (_focusNode.hasFocus == false) {
      final value = _playlistNameC.text.trim();
      if (value.isEmpty) {
        _playlistNameC.text = widget.title;
      } else {
        widget.onSubmit?.call(value);
      }
    }
  }

  @override
  void dispose() {
    _playlistNameC.dispose();
    _focusNode.removeListener(listener);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFieldWidget(
      focusNode: widget.focusNode,
      hintText: tr('untitled'),
      controller: _playlistNameC,
      cursorColor: AppColor.white,
      style: theme.textTheme.ppMori700White14,
      hintStyle: theme.textTheme.ppMori700Black14
          .copyWith(color: AppColor.disabledColor),
      textAlign: TextAlign.center,
      border: InputBorder.none,
      onFieldSubmitted: (value) {
        widget.onSubmit?.call(value);
      },
    );
  }
}
