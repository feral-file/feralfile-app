import 'package:autonomy_flutter/design/build/primitives.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/debouce_util.dart';
import 'package:flutter/material.dart';

class CoreButton extends StatefulWidget {
  const CoreButton({
    super.key,
    this.onTap,
    this.text,
    this.leftIcon,
    this.rightIcon,
    this.textColor,
    this.color,
    this.disabledColor,
    this.indicatorColor,
    this.padding,
    this.borderRadius = 75,
    this.borderColor,
    this.enabled = true,
    this.isAsync = false,
    this.textStyle,
    this.gap = 10,
  });
  final String? text;
  final Widget? leftIcon;
  final Widget? rightIcon;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final Color? textColor;
  final Color? color;
  final Color? disabledColor;
  final Color? indicatorColor;
  final double borderRadius;
  final Color? borderColor;
  final double gap;
  final bool enabled;
  final bool isAsync;
  final Function()? onTap;

  @override
  State<CoreButton> createState() => _CoreButtonState();
}

class _CoreButtonState extends State<CoreButton> {
  bool _isProcessing = false;

  late final String randomKey;

  @override
  void initState() {
    super.initState();
    randomKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _handleAsyncTap() {
    withDebounce(
      key: randomKey,
      () async {
        setState(() {
          _isProcessing = true;
        });
        await widget.onTap?.call();
        if (!mounted) {
          return;
        }

        setState(() {
          _isProcessing = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = widget.disabledColor ?? PrimitivesTokens.colorsGrey;
    return SizedBox(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: widget.enabled
              ? widget.color ?? PrimitivesTokens.colorsLightBlue
              : disabledColor,
          shadowColor: Colors.transparent,
          padding: widget.padding ?? const EdgeInsets.all(10),
          disabledForegroundColor: disabledColor,
          disabledBackgroundColor: disabledColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            side: BorderSide(
              color: widget.borderColor ?? Colors.transparent,
            ),
          ),
        ),
        onPressed: widget.enabled
            ? () {
                widget.isAsync ? _handleAsyncTap() : widget.onTap?.call();
              }
            : null,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // if (_isProcessing) ...[
              //   Container(
              //     height: 12,
              //     width: 12,
              //     margin: const EdgeInsets.only(right: 8),
              //     child: CircularProgressIndicator(
              //       color: widget.indicatorColor ?? theme.colorScheme.primary,
              //       backgroundColor: theme.colorScheme.surface,
              //       strokeWidth: 2,
              //     ),
              //   ),
              //   SizedBox(width: widget.gap),
              // ],
              if (widget.leftIcon != null) ...[
                widget.leftIcon!,
                SizedBox(width: widget.gap),
              ],
              Text(
                widget.text ?? '',
                style: widget.textStyle ??
                    theme.textTheme.body.copyWith(
                      color: widget.textColor ?? PrimitivesTokens.colorsBlack,
                    ),
              ),
              if (widget.rightIcon != null) ...[
                SizedBox(width: widget.gap),
                widget.rightIcon!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
