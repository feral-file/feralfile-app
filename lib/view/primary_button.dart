import 'package:autonomy_flutter/theme/app_color.dart';
import 'package:autonomy_flutter/theme/extensions/color_extension.dart';
import 'package:autonomy_flutter/theme/extensions/theme_extension.dart';
import 'package:autonomy_flutter/util/debouce_util.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final Function()? onTap;
  final Color? color;
  final Color? disabledColor;
  final String? text;
  final Color? textColor;
  final double? width;
  final bool isProcessing;
  final bool enabled;
  final Color? indicatorColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? elevatedPadding;
  final double borderRadius;
  final Color? borderColor;

  const PrimaryButton({
    super.key,
    this.onTap,
    this.color,
    this.disabledColor,
    this.text,
    this.textColor,
    this.width,
    this.enabled = true,
    this.isProcessing = false,
    this.indicatorColor,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
    this.elevatedPadding,
    this.borderRadius = 32,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = this.disabledColor ?? AppColor.disabledColor;
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? color ?? AppColor.feralFileLightBlue : disabledColor,
          padding: elevatedPadding,
          shadowColor: Colors.transparent,
          disabledForegroundColor: disabledColor,
          disabledBackgroundColor: disabledColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: borderColor ?? Colors.transparent,
            ),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Padding(
          padding: padding,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isProcessing)
                  Container(
                    height: 14,
                    width: 14,
                    margin: const EdgeInsets.only(right: 8),
                    child: CircularProgressIndicator(
                      color: indicatorColor ?? theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  text ?? '',
                  style: theme.textTheme.ppMori400Black14
                      .copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  final Function()? onTap;
  final Color? color;
  final String? text;
  final double? width;
  final bool isProcessing;
  final bool enabled;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsets padding;

  const OutlineButton({
    super.key,
    this.onTap,
    this.color,
    this.text,
    this.width,
    this.enabled = true,
    this.isProcessing = false,
    this.textColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? theme.auGreyBackground,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: borderColor ?? Colors.white),
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Padding(
          padding: padding,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isProcessing)
                  Container(
                    height: 14,
                    width: 14,
                    margin: const EdgeInsets.only(right: 8),
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      backgroundColor: theme.colorScheme.surface,
                      strokeWidth: 2,
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  text ?? '',
                  style: theme.textTheme.ppMori400White14.copyWith(
                      color: textColor ??
                          (!enabled ? AppColor.disabledColor : null)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrimaryAsyncButton extends StatefulWidget {
  final Function()? onTap;
  final Color? color;
  final String? text;
  final Color? textColor;
  final double? width;
  final bool enabled;
  final String? processingText;
  final Color? borderColor;
  final double borderRadius;

  const PrimaryAsyncButton(
      {super.key,
      this.onTap,
      this.color,
      this.textColor,
      this.text,
      this.width,
      this.enabled = true,
      this.borderColor,
      this.borderRadius = 32,
      this.processingText});

  @override
  State<PrimaryAsyncButton> createState() => _PrimaryAsyncButtonState();
}

class _PrimaryAsyncButtonState extends State<PrimaryAsyncButton> {
  bool _isProcessing = false;

  late final String randomKey;

  @override
  void initState() {
    super.initState();
    randomKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) => PrimaryButton(
        onTap: () {
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
        },
        color: widget.color,
        text: _isProcessing && widget.processingText != null
            ? widget.processingText
            : widget.text,
        textColor: widget.textColor,
        borderColor: widget.borderColor,
        width: widget.width,
        enabled: widget.enabled && !_isProcessing,
        isProcessing: _isProcessing,
      );
}

class CustomPrimaryButton extends StatelessWidget {
  final Function()? onTap;
  final Color? color;
  final Color? disabledColor;
  final Color? textColor;
  final bool isProcessing;
  final bool enabled;
  final Color? indicatorColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Widget child;

  const CustomPrimaryButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.disabledColor,
    this.enabled = true,
    this.isProcessing = false,
    this.borderColor,
    this.indicatorColor,
    this.padding = const EdgeInsets.symmetric(vertical: 13),
    this.borderRadius = 32,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = this.disabledColor ?? AppColor.disabledColor;
    return SizedBox(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? color ?? AppColor.feralFileLightBlue : disabledColor,
          shadowColor: Colors.transparent,
          padding: padding,
          disabledForegroundColor: disabledColor,
          disabledBackgroundColor: disabledColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: borderColor ?? Colors.transparent,
            ),
          ),
        ),
        onPressed: enabled ? onTap : null,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isProcessing)
                Container(
                  height: 12,
                  width: 12,
                  margin: const EdgeInsets.only(right: 8),
                  child: CircularProgressIndicator(
                    color: indicatorColor ?? theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surface,
                    strokeWidth: 2,
                  ),
                )
              else
                const SizedBox(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class CustomPrimaryAsyncButton extends StatefulWidget {
  final Function()? onTap;
  final Widget child;
  final Color? color;
  final bool enabled;
  final String? processingText;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  const CustomPrimaryAsyncButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.enabled = true,
    this.processingText,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(vertical: 2),
  });

  @override
  State<CustomPrimaryAsyncButton> createState() =>
      _CustomPrimaryAsyncButtonState();
}

class _CustomPrimaryAsyncButtonState extends State<CustomPrimaryAsyncButton> {
  bool _isProcessing = false;

  late final String randomKey;

  @override
  void initState() {
    super.initState();
    randomKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPrimaryButton(
      onTap: () {
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
      },
      child: widget.child,
      color: widget.color,
      borderColor: widget.borderColor,
      enabled: widget.enabled && !_isProcessing,
      isProcessing: _isProcessing,
      padding: widget.padding,
    );
  }
}

class TextAsyncButton extends StatefulWidget {
  const TextAsyncButton({
    required this.color,
    super.key,
    this.onTap,
    this.text,
    this.processingText,
  });

  final dynamic Function()? onTap;
  final Color color;
  final String? text;
  final String? processingText;

  @override
  State<TextAsyncButton> createState() => _TextAsyncButtonState();
}

class _TextAsyncButtonState extends State<TextAsyncButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing)
            Container(
              height: 14,
              width: 14,
              margin: const EdgeInsets.only(right: 8),
              child: CircularProgressIndicator(
                color: widget.color,
                backgroundColor: Colors.transparent,
                strokeWidth: 2,
              ),
            ),
          TextButton(
            onPressed: () {
              withDebounce(
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
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isProcessing ? widget.processingText ?? '' : widget.text ?? '',
              style: Theme.of(context)
                  .textTheme
                  .ppMori400Black14
                  .copyWith(color: widget.color),
            ),
          ),
        ],
      );
}
